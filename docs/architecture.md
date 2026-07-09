## Architecture

#### Overview Diagram

<img src="./doc_images/architectural_overview_diagram.png" alt="drawing" title="Overview architecture." width="1000"/>
<br>

**Openlibrary:**
- The Openlibrary API is used purely as a read/lookup source. There is no direct interaction between Openlibrary and FireBase.
- App code acts as the middle-man to transform the information from Openlibrary and passes it to FireStore

**FireBase Authentication:**
- FireBase Authentication issues a unique ID (uid) on registration
- FireBase Authentication and FireStore do not interact directly with each other. Again, the app code acts as the middle-man passing the uid

**FireStore:**
- Any information/data associated with a user is stored in FireStore. Anytime this is updated, changed, added to, or removed FireStore is involved. Any read or write type operation.


#### New User Registration Flow

The following diagram shows the flow of a user registering and logging a book and how this interact with the major components 


```mermaid
flowchart TD
    A([New user registers]) --> B[Firebase Authentication\ncreates account & issues uid]
    B --> C[Flutter app creates user profile\nin Firestore using that uid]
    C --> D[Verification email sent\nuser confirms email]
    D --> E[User signs in]
    E --> F[Firebase Authentication\nverifies credentials]
    F --> G[Flutter app routes user\ninto the app]
    G --> H[User searches for a book]
    H --> I[Flutter app queries\nOpenLibrary API]
    I --> J[OpenLibrary returns\nbook results & cover images]
    J --> K[User selects a book\nand submits a review]
    K --> L[Flutter app saves review\nto Firestore under that uid]
    L --> M([Book is logged ✓])
```
