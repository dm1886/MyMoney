# MyMoney cross-platform delivery

- iOS remains SwiftUI/SwiftData; Android lives in android/ using Kotlin/Compose.
- Implement every functional change on both platforms, or explicitly record why it is platform-specific and the outstanding parity work in docs/ANDROID_PARITY.md.
- Never claim parity from successful compilation alone. Verify financial results, persistence and rendered screens using equivalent inputs on both platforms.
- Preserve existing iOS data and offline access. Never silently upload or replace a local/CloudKit library.
- Use decimal monetary arithmetic and saved exchange-rate snapshots. Never aggregate different currencies without an explicit conversion.
- Firebase data is private by default. Only accepted, authorized household members can access shared data; membership/roles cannot be self-elevated.
- Do not log credentials, ID tokens, expense contents or personal identifiers. No production secrets or service-account keys in the repository.
- Before reporting completion, run Android tests/build, relevant iOS tests and Firebase Rules tests for authorization changes. List unverified gates honestly.

## Visual parity and adaptive sizing

- Treat the existing iOS Orb UI as the visual reference: same Sora font, semantic sizes/weights, palette, spacing, shapes, hierarchy and navigation. Do not substitute default Material typography or redesign Android independently.
- Adapt layout to available dp/points and system font scaling; never size UI in physical pixels, disable user font scaling, or stretch a phone layout to fill a tablet. Preserve full monetary values.
- Verify compact phones, normal phones, tablets and enlarged text. Record rendered comparison gaps; passing layout tests alone is not proof of complete visual parity.
