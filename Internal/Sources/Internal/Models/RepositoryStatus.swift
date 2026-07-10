//
//  RepositoryStatus.swift
//  Internal
//

import Foundation

public struct RepositoryStatus: Sendable, Equatable, Codable {
	public enum Kind: String, Sendable, Codable {
		case unknown, checking, cloning, clean, noRemote
		case pulled, discardedAndPulled
		case needsPush, dirty, diverged, error
	}

	public var kind: Kind = .unknown
	public var localAhead: Int = 0
	public var remoteAhead: Int = 0
	public var dirtyFiles: [String] = []
	public var branch: String = ""
	public var remote: String = ""
	public var remoteURL: String?
	public var message: String?
	public var lastChecked: Date?
	public var lastCommitDate: Date?

	public static let unknown = RepositoryStatus()

	public var needsPush: Bool { kind == .needsPush }
	public var isBusy: Bool { kind == .checking }
	public var hasRecentCommit: Bool {
		guard let lastCommitDate else { return false }
		return lastCommitDate.timeIntervalSinceNow > -24 * 60 * 60
	}
	public var hasProblem: Bool {
		kind == .diverged || kind == .dirty || kind == .error
	}

	public var sortTier: Int {
		switch kind {
		case .needsPush, .dirty, .diverged, .error: 0
		case .pulled, .discardedAndPulled: 1
		case .clean, .noRemote, .unknown, .checking, .cloning: 2
		}
	}
}
