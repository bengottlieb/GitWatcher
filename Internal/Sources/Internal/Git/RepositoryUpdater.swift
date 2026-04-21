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

		guard status.kind != .error, status.kind != .noRemote else { return status }
		let branch = status.branch
		let remote = status.remote
		guard !remote.isEmpty else { return status }

		let dirty = (try? await runner.dirtyFiles()) ?? []
		let allWhitelisted = !dirty.isEmpty && dirty.allSatisfy { isWhitelisted($0) }

		do {
			if status.remoteAhead > 0, dirty.isEmpty, status.localAhead == 0 {
				try await runner.pull(remote: remote, branch: branch)
				return await reinspect(kind: .pulled, priorRemote: status.remoteAhead)
			}
			if status.remoteAhead > 0, allWhitelisted, status.localAhead == 0 {
				try await runner.discard(files: dirty)
				try await runner.pull(remote: remote, branch: branch)
				return await reinspect(kind: .discardedAndPulled, priorRemote: status.remoteAhead)
			}
		} catch {
			status.kind = .error
			status.message = (error as? GitError)?.stderr ?? error.localizedDescription
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
		return await RepositoryInspector(repository: repository).checkStatus()
	}

	private func isWhitelisted(_ file: DirtyFile) -> Bool {
		let name = file.basename
		return whitelist.contains { $0 == name || $0 == file.path }
	}

	private func reinspect(kind: RepositoryStatus.Kind, priorRemote: Int) async -> RepositoryStatus {
		var refreshed = await RepositoryInspector(repository: repository).checkStatus()
		refreshed.kind = kind
		refreshed.remoteAhead = priorRemote
		return refreshed
	}
}
