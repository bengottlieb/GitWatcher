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

	public func sortedRepositories(mode: SortMode) -> [Repository] {
		switch mode {
		case .alphabetical:
			return repositories.sorted { lhs, rhs in
				let lt = status(for: lhs).sortTier
				let rt = status(for: rhs).sortTier
				if lt != rt { return lt < rt }
				return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
			}
		case .chronological:
			return repositories.sorted { lhs, rhs in
				let lDate = status(for: lhs).lastCommitDate ?? .distantPast
				let rDate = status(for: rhs).lastCommitDate ?? .distantPast
				if lDate != rDate { return lDate > rDate }
				return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
			}
		}
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
		statuses[id] = RepositoryStatus(kind: .checking)
		let updater = RepositoryUpdater(repository: repo, whitelist: whitelist)
		statuses[id] = await updater.update()
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
