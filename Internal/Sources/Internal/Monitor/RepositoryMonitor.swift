//
//  RepositoryMonitor.swift
//  Internal
//

import AppKit
import Foundation
import Observation
import SharedSettings

@MainActor
@Observable
public final class RepositoryMonitor {
	public static let shared = RepositoryMonitor()

	public private(set) var repositories: [Repository]
	public private(set) var statuses: [UUID: RepositoryStatus] = [:]
	public private(set) var isRefreshing = false
	public private(set) var lastRefreshDuration: Duration?
	public private(set) var lastRefreshAt: Date?
	public var whitelist: [String] {
		didSet {
			guard !suppressPersist else { return }
			SharedSettings[WhitelistKey.self] = whitelist
		}
	}

	@ObservationIgnored private var suppressPersist = false
	@ObservationIgnored private var cloningIDs: Set<UUID> = []
	@ObservationIgnored nonisolated(unsafe) private var externalChangeToken: NSObjectProtocol?
	@ObservationIgnored nonisolated(unsafe) private var wakeObservers: [NSObjectProtocol] = []
	@ObservationIgnored private var autoRefreshTask: Task<Void, Never>?

	public static let autoRefreshInterval: Duration = .seconds(15 * 60)

	private init() {
		Self.migrateRepositoriesToCloudIfNeeded()
		self.repositories = SharedSettings[RepositoriesKey.self]
		self.whitelist = SharedSettings[WhitelistKey.self]
		externalChangeToken = NotificationCenter.default.addObserver(
			forName: SharedSettings.didChangeExternallyNotification,
			object: nil,
			queue: nil
		) { [weak self] note in
			let changed = note.sharedSettingsChangedKeys
			Task { @MainActor [weak self] in
				self?.reloadCloudValues(changedKeys: changed)
			}
		}
		installWakeObservers()
		startAutoRefresh()
	}

	deinit {
		if let token = externalChangeToken {
			NotificationCenter.default.removeObserver(token)
		}
		for token in wakeObservers {
			NSWorkspace.shared.notificationCenter.removeObserver(token)
			DistributedNotificationCenter.default.removeObserver(token)
		}
		autoRefreshTask?.cancel()
	}

	private func installWakeObservers() {
		let workspaceCenter = NSWorkspace.shared.notificationCenter
		let workspaceNames: [Notification.Name] = [
			NSWorkspace.didWakeNotification,
			NSWorkspace.screensDidWakeNotification
		]
		for name in workspaceNames {
			let token = workspaceCenter.addObserver(
				forName: name, object: nil, queue: nil
			) { [weak self] _ in
				Task { @MainActor [weak self] in
					await self?.refreshAll()
				}
			}
			wakeObservers.append(token)
		}
		let screensaverToken = DistributedNotificationCenter.default.addObserver(
			forName: Notification.Name("com.apple.screensaver.didstop"),
			object: nil,
			queue: nil
		) { [weak self] _ in
			Task { @MainActor [weak self] in
				await self?.refreshAll()
			}
		}
		wakeObservers.append(screensaverToken)
	}

	private func startAutoRefresh() {
		autoRefreshTask?.cancel()
		autoRefreshTask = Task { [weak self] in
			while !Task.isCancelled {
				await self?.refreshAll()
				try? await Task.sleep(for: Self.autoRefreshInterval)
			}
		}
	}

	public var hasPendingPushes: Bool {
		statuses.values.contains { $0.needsPush }
	}

	public var hasProblems: Bool {
		statuses.values.contains { $0.hasProblem }
	}

	public var attentionCount: Int {
		statuses.values.filter { $0.needsPush || $0.hasProblem }.count
	}

	public func sortedRepositories(mode: SortMode) -> [Repository] {
		let existing = repositories.filter(\.existsOnDisk)
		switch mode {
		case .alphabetical:
			return existing.sorted { lhs, rhs in
				let lt = status(for: lhs).sortTier
				let rt = status(for: rhs).sortTier
				if lt != rt { return lt < rt }
				return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
			}
		case .chronological:
			return existing.sorted { lhs, rhs in
				let lDate = status(for: lhs).lastCommitDate ?? .distantPast
				let rDate = status(for: rhs).lastCommitDate ?? .distantPast
				if lDate != rDate { return lDate > rDate }
				return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
			}
		}
	}

	public func missingRepositories() -> [Repository] {
		repositories
			.filter { !$0.existsOnDisk }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	public func addRepository(at url: URL) {
		guard !repositories.contains(where: { $0.url == url }) else { return }
		let repo = Repository(url: url)
		repositories.append(repo)
		persistRepositories()
		Task { await refresh(repositoryID: repo.id) }
	}

	public func removeRepository(id: UUID) {
		repositories.removeAll { $0.id == id }
		statuses.removeValue(forKey: id)
		persistRepositories()
	}

	public func status(for repo: Repository) -> RepositoryStatus {
		statuses[repo.id] ?? .unknown
	}

	public func refreshAll() async {
		guard !isRefreshing else { return }
		isRefreshing = true
		defer { isRefreshing = false }
		let start = ContinuousClock.now
		let ids = repositories.map(\.id)
		await withTaskGroup(of: Void.self) { group in
			for id in ids {
				group.addTask { [weak self] in
					await self?.refresh(repositoryID: id)
				}
			}
		}
		lastRefreshDuration = ContinuousClock.now - start
		lastRefreshAt = Date()
	}

	public func refresh(repositoryID id: UUID) async {
		guard let repo = repositories.first(where: { $0.id == id }) else { return }
		guard !cloningIDs.contains(id), repo.existsOnDisk else { return }
		statuses[id] = RepositoryStatus(kind: .checking)
		let updater = RepositoryUpdater(repository: repo, whitelist: whitelist)
		let status = await updater.update()
		statuses[id] = status
		if let url = status.remoteURL { rememberRemoteURL(url, forID: id) }
	}

	public func cloneAndRefresh(repositoryID id: UUID, remoteURLOverride: String? = nil) async {
		guard let repo = repositories.first(where: { $0.id == id }) else { return }
		guard !cloningIDs.contains(id) else { return }
		let override = remoteURLOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let remoteURL = Self.resolveCloneURL(override: override, persisted: repo.remoteURL) else {
			statuses[id] = RepositoryStatus(kind: .error, message: "No remote URL is known for this repository.")
			return
		}
		guard await performClone(repo, remoteURL: remoteURL) else { return }
		if let override, !override.isEmpty { rememberRemoteURL(override, forID: id) }
		await refresh(repositoryID: id)
	}

	private func performClone(_ repo: Repository, remoteURL: String) async -> Bool {
		cloningIDs.insert(repo.id)
		defer { cloningIDs.remove(repo.id) }
		statuses[repo.id] = RepositoryStatus(kind: .cloning)
		do {
			try await RepositoryCloner(repository: repo, remoteURL: remoteURL).clone()
			return true
		} catch {
			let message = (error as? GitError)?.stderr ?? error.localizedDescription
			statuses[repo.id] = RepositoryStatus(kind: .error, message: message)
			return false
		}
	}

	nonisolated static func resolveCloneURL(override: String?, persisted: String?) -> String? {
		let trimmed = override?.trimmingCharacters(in: .whitespacesAndNewlines)
		if let trimmed, !trimmed.isEmpty { return trimmed }
		if let persisted, !persisted.isEmpty { return persisted }
		return nil
	}

	private func rememberRemoteURL(_ url: String, forID id: UUID) {
		guard let index = repositories.firstIndex(where: { $0.id == id }),
		      repositories[index].remoteURL != url else { return }
		repositories[index].remoteURL = url
		persistRepositories()
	}

	public func push(repositoryID id: UUID) async {
		guard let repo = repositories.first(where: { $0.id == id }) else { return }
		statuses[id] = RepositoryStatus(kind: .checking)
		let updater = RepositoryUpdater(repository: repo, whitelist: whitelist)
		statuses[id] = await updater.push()
	}

	private func persistRepositories() {
		SharedSettings[RepositoriesKey.self] = repositories
	}

	private func reloadCloudValues(changedKeys: [String]?) {
		let affects = { (name: String) in
			changedKeys == nil || changedKeys?.contains(name) == true
		}
		if affects(WhitelistKey.name) {
			suppressPersist = true
			whitelist = SharedSettings[WhitelistKey.self]
			suppressPersist = false
		}
		if affects(RepositoriesKey.name) {
			applyRemoteRepositories(SharedSettings[RepositoriesKey.self])
		}
	}

	private func applyRemoteRepositories(_ updated: [Repository]) {
		let newIDs = Set(updated.map(\.id))
		let existingIDs = Set(repositories.map(\.id))
		repositories = updated
		statuses = statuses.filter { newIDs.contains($0.key) }
		let added = newIDs.subtracting(existingIDs)
		for id in added {
			Task { await self.refresh(repositoryID: id) }
		}
	}

	private static func migrateRepositoriesToCloudIfNeeded() {
		let existing = SharedSettings[RepositoriesKey.self]
		guard existing.isEmpty else { return }
		let defaults = UserDefaults.standard
		guard let data = defaults.data(forKey: RepositoriesKey.name),
		      let legacy = try? JSONDecoder().decode([Repository].self, from: data),
		      !legacy.isEmpty else { return }
		SharedSettings[RepositoriesKey.self] = legacy
		defaults.removeObject(forKey: RepositoriesKey.name)
	}
}
