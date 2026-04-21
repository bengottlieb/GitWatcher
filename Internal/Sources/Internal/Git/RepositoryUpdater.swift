//
//  RepositoryUpdater.swift
//  Internal
//

import Foundation

struct RepositoryUpdater: Sendable {
	let repository: Repository
	let whitelist: [String]

	private var runner: GitRunner { GitRunner(repoPath: repository.url) }

	func update() async -> RepositoryStatus {
		var status = await RepositoryInspector(repository: repository).checkStatus()
		if status.kind == .error { return status }

		let dirty = (try? await runner.dirtyFiles()) ?? []
		let allWhitelisted = !dirty.isEmpty && dirty.allSatisfy { isWhitelisted($0) }

		if !status.remote.isEmpty, status.kind != .noRemote {
			do {
				if status.remoteAhead > 0, dirty.isEmpty, status.localAhead == 0 {
					try await runner.pull(remote: status.remote, branch: status.branch)
					return await reinspect(kind: .pulled, priorRemote: status.remoteAhead)
				}
				if status.remoteAhead > 0, allWhitelisted, status.localAhead == 0 {
					try await runner.discard(files: dirty)
					try await runner.pull(remote: status.remote, branch: status.branch)
					return await reinspect(kind: .discardedAndPulled, priorRemote: status.remoteAhead)
				}
			} catch {
				status.kind = .error
				status.message = (error as? GitError)?.stderr ?? error.localizedDescription
				return status
			}
		}

		if allWhitelisted {
			status = treatDirtyAsClean(status)
		}
		return status
	}

	func push() async -> RepositoryStatus {
		var status = await RepositoryInspector(repository: repository).checkStatus()
		guard !status.remote.isEmpty else { return status }
		do {
			try await runner.push(remote: status.remote, branch: status.branch)
		} catch {
			status.kind = .error
			status.message = (error as? GitError)?.stderr ?? error.localizedDescription
			return status
		}
		var refreshed = await RepositoryInspector(repository: repository).checkStatus()
		let dirty = (try? await runner.dirtyFiles()) ?? []
		if !dirty.isEmpty, dirty.allSatisfy({ isWhitelisted($0) }) {
			refreshed = treatDirtyAsClean(refreshed)
		}
		return refreshed
	}

	private func isWhitelisted(_ file: DirtyFile) -> Bool {
		let name = file.basename
		return whitelist.contains { $0 == name || $0 == file.path }
	}

	private func treatDirtyAsClean(_ status: RepositoryStatus) -> RepositoryStatus {
		var updated = status
		if status.localAhead > 0, status.remoteAhead > 0 {
			updated.kind = .diverged
		} else if status.localAhead > 0 {
			updated.kind = .needsPush
		} else if status.remote.isEmpty {
			updated.kind = .noRemote
		} else {
			updated.kind = .clean
		}
		return updated
	}

	private func reinspect(kind: RepositoryStatus.Kind, priorRemote: Int) async -> RepositoryStatus {
		var refreshed = await RepositoryInspector(repository: repository).checkStatus()
		refreshed.kind = kind
		refreshed.remoteAhead = priorRemote
		return refreshed
	}
}
