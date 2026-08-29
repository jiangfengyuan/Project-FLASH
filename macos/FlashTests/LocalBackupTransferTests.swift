// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import Flash

@Suite("LocalBackupTransfer")
struct LocalBackupTransferTests {
    @Test func generatedPINIsAlwaysFourDigits() {
        for _ in 0..<200 {
            let pin = LocalBackupSender.generatePIN()
            let onlyDigits = pin.allSatisfy { $0.isNumber }
            #expect(pin.count == 4)
            #expect(onlyDigits)
        }
    }
}
