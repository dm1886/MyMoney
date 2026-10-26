# Firebase foundation and privacy decisions

Updated 2026-10-26, Macau time. This is an engineering checklist, not a legal opinion or a ready-to-publish privacy policy.

## Cloud state

- Dedicated Firebase project: `dm1886-mymoney`.
- Android application ID: `com.damianomiazzi.mymoney`.
- iOS bundle ID: `damianomiazzi.MyMoney`.
- The CLI is authenticated. Credentials stay in its local credential store.
- Firestore security rules have been deployed to the empty project after emulator tests.
- The CLI deployment initialized the default Firestore database in `nam5` (United States). It is **not** an EU-only deployment. The earlier explicit Frankfurt creation attempt failed before API enablement. Decide on database location and international-transfer obligations before enabling production financial uploads. A database's location cannot be edited in place.
- Firebase Authentication initialized in console and email/password provider enabled. Debug signup is tested against Auth Emulator; no real cloud account was registered.
- No real user expenses have been uploaded, no billing plan was upgraded and no paid Functions deployment was made.
- Distribution requested: worldwide except China. This exclusion is not yet configured in either store. Adult-only use has not been confirmed.

## Intended model

Firebase Authentication identifies each person. Financial accounts are separate records. Private expenses stay under the owner's UID. Shared expenses belong to a household with accepted members and owner/editor/viewer roles. A client cannot add itself to a household, change roles, or create invitations directly. Those operations require a trusted server implementation, which is not yet deployed.

Existing iOS SwiftData/CloudKit data must remain available. First login must not silently upload, overwrite, or associate an existing library to a different person. An explicit migration and sharing selection is required. Android local libraries are separated by UID.

## Requirements before public launch

1. Identify the legal entity acting as controller and markets/ages served. Worldwide distribution needs assessment beyond GDPR, including relevant local privacy and children's rules.
2. Establish the appropriate legal basis for account hosting, synchronization and sharing. Consent is not automatically the right basis for core contractual services. AI processing and optional features require separate analysis and clear disclosure.
3. Publish accurate privacy information: data categories, purposes, recipients, processors, locations/transfers, retention, contacts, rights and deletion.
4. Review Google's applicable processing terms and transfer arrangements. Selecting a Firestore EU region alone would not guarantee all Firebase services are EU-only.
5. Implement invitations with explicit acceptance, scope selection, revocation, authorization tests and cache handling. Private accounts must not become family-visible by default.
6. Implement export and full account deletion across Auth, Firestore subcollections, household membership, uploaded files, backups/retention and any later AI-provider files. Deleting only the Auth user is insufficient.
7. Minimize stored data. Expense notes and receipt images can reveal health, religion or other sensitive facts. Do not assume every receipt contains only ordinary financial data.
8. Add App Check/rate limiting, monitoring without financial payloads, incident handling and recovery. Keep all collections default-deny.
9. Complete App Store privacy and Google Play Data Safety disclosures from actual SDK/data behavior. Configure China exclusion in stores.
10. Have a qualified privacy adviser review the implemented flows and documentation before launch.

## Official references

- Firebase roles and processing terms: https://firebase.google.com/support/privacy
- EDPB data protection basics and legal bases: https://www.edpb.europa.eu/sme/learn-the-basics/data-protection-basics_en
- EDPB compliance and privacy by default: https://www.edpb.europa.eu/sme/be-compliant/be-compliant_en
- Firestore authorization conditions: https://firebase.google.com/docs/firestore/security/rules-conditions
