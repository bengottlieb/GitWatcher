//
//  RepositoryInspector.swift
//  Internal
//

import Foundation

struct RepositoryInspector: Sendable {
	let repository: Repository

	private var runner: GitRunner { GitRunner(repoPath: repository.url) }

	func checkStatus() async -> RepositoryStatus {
		var status = RepositoryStatus(kind: .checking)
		status.lastChecked = Date()
		do {
			let branch = try await runner.currentBranch()
			status.branch = branch
			status.lastCommitDate = try? await runner.lastCommitDate()
			guard let remote = try await runner.firstRemote() else {
				let dirty = (try? await runner.dirtyFiles()) ?? []
				status.dirtyFiles = dirty.map(\.path)
				status.kind = dirty.isEmpty ? .noRemote : .dirty
				return status
			}
			status.remote = remote
			status.remoteURL = try? await runner.remoteURL(name: remote)
			try await runner.fetch(remote: remote)

			let hasRemoteBranch = try await runner.remoteBranchExists(
				remote: remote, branch: branch
			)
			let counts = hasRemoteBranch
				? try await runner.counts(remote: remote, branch: branch)
				: (local: 0, remote: 0)
			status.localAhead = counts.local
			status.remoteAhead = counts.remote

			let dirty = try await runner.dirtyFiles()
			status.dirtyFiles = dirty.map(\.path)

			status.kind = classify(
				local: counts.local,
				remote: counts.remote,
				dirty: !dirty.isEmpty,
				hasRemoteBranch: hasRemoteBranch
			)
			return status
		} catch {
			status.kind = .error
			status.message = (error as? GitError)?.stderr ?? error.localizedDescription
			return status
		}
	}

	private func classify(local: Int, remote: Int, dirty: Bool, hasRemoteBranch: Bool) -> RepositoryStatus.Kind {
		if !hasRemoteBranch && local == 0 && !dirty { return .clean }
		if dirty && (local > 0 || remote > 0) { return .diverged }
		if dirty { return .dirty }
		if local > 0 && remote > 0 { return .diverged }
		if remote > 0 { return .clean }
		if local > 0 { return .needsPush }
		return .clean
	}
}
