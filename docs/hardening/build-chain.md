# Build-chain checkpoint

No dependency/SDK upgrade, signing change, deployment-target change or new permission. Checked-in toolchain/dependency versions remain as inventoried in the baseline; immutable CI action SHAs remain.

Android's Gradle8.14.3 distribution was version-pinned but lacked `distributionSha256Sum`. It now pins the official binary ZIP SHA256 `bd71102213493060956ec229d946beee57158dbd89d0e62b91bca0fa2c5f3531`. The checked-in wrapper JAR independently hashes to official `7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172`. Both were checked against the [official release checksum list](https://gradle.org/release-checksums/) on2026-10-25. No JAR/distribution replacement.

[Gradle's wrapper guidance](https://docs.gradle.org/current/userguide/gradle_wrapper.html) describes distribution checksum verification. The property protects a fresh wrapper distribution download; it does not verify an already-extracted cache or authenticate every dependency. Existing offline Debug/Release JVM93-each and APK gates ran against the existing pinned toolchain. A cached wrapper launch is only a configuration sanity check, not proof that the fresh-download mismatch path was exercised.

Remaining: transitive dependency verification/lock coverage, optional Aliyun mirror trust, developer/CI cache compromise, platform SDK provenance and published-artifact verification. A version-pinned package is not thereby proven maintained or vulnerability-free. No unsupported supply-chain assurance or obfuscation claim is made; no secrets/keystores are inspected or remediated in this branch.
