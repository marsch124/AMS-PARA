import Foundation
import XCTest
@testable import AMSParaCore

func makeTemporaryVault(file: StaticString = #filePath, line: UInt = #line) throws -> Vault {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ams-para-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let vault = try Vault(rootURL: url)
    try vault.bootstrap()
    return vault
}

func removeVault(_ vault: Vault) {
    try? FileManager.default.removeItem(at: vault.rootURL)
}
