//
//  GitInvocation.swift
//  Internal
//

import Foundation

final class GitInvocation: @unchecked Sendable {
	private let process = Process()
	private let outPipe = Pipe()
	private let errPipe = Pipe()
	private let lock = NSLock()
	private var outData = Data()
	private var errData = Data()
	private var continuation: CheckedContinuation<String, Error>?
	private let args: [String]

	init(args: [String], directory: URL) {
		self.args = args
		process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		process.arguments = ["git"] + args
		process.currentDirectoryURL = directory
		var env = ProcessInfo.processInfo.environment
		env["GIT_TERMINAL_PROMPT"] = "0"
		env["GIT_OPTIONAL_LOCKS"] = "0"
		process.environment = env
		process.standardOutput = outPipe
		process.standardError = errPipe
	}

	func run() async throws -> String {
		try await withCheckedThrowingContinuation { cont in
			lock.lock()
			continuation = cont
			lock.unlock()
			outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
				self?.handleAvailable(from: handle, isStdout: true)
			}
			errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
				self?.handleAvailable(from: handle, isStdout: false)
			}
			process.terminationHandler = { [weak self] proc in
				self?.finish(with: proc)
			}
			do {
				try process.run()
			} catch {
				outPipe.fileHandleForReading.readabilityHandler = nil
				errPipe.fileHandleForReading.readabilityHandler = nil
				process.terminationHandler = nil
				resumeIfNeeded(.failure(error))
			}
		}
	}

	private func handleAvailable(from handle: FileHandle, isStdout: Bool) {
		let data = handle.availableData
		if data.isEmpty {
			handle.readabilityHandler = nil
			return
		}
		lock.lock()
		if isStdout { outData.append(data) } else { errData.append(data) }
		lock.unlock()
	}

	private func finish(with proc: Process) {
		outPipe.fileHandleForReading.readabilityHandler = nil
		errPipe.fileHandleForReading.readabilityHandler = nil
		if let remaining = try? outPipe.fileHandleForReading.readToEnd() {
			lock.lock(); outData.append(remaining); lock.unlock()
		}
		if let remaining = try? errPipe.fileHandleForReading.readToEnd() {
			lock.lock(); errData.append(remaining); lock.unlock()
		}
		lock.lock()
		let stdout = String(data: outData, encoding: .utf8) ?? ""
		let stderr = String(data: errData, encoding: .utf8) ?? ""
		lock.unlock()
		if proc.terminationStatus == 0 {
			resumeIfNeeded(.success(stdout))
		} else {
			resumeIfNeeded(.failure(GitError(
				code: proc.terminationStatus,
				stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
				command: args.joined(separator: " ")
			)))
		}
	}

	private func resumeIfNeeded(_ result: Result<String, Error>) {
		lock.lock()
		let cont = continuation
		continuation = nil
		lock.unlock()
		cont?.resume(with: result)
	}
}
