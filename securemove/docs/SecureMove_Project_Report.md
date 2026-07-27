
# ACRONYMS AND ABBREVIATIONS

API: Application Programming Interface

CRUD: Create, Read, Update, Delete

DBMS: Database Management System

HTTP: Hypertext Transfer Protocol

JWT: JSON Web Token

QR: Quick Response

RBAC: Role-Based Access Control

REST: Representational State Transfer

SDK: Software Development Kit

UI: User Interface

UX: User Experience

# CHAPTER 1: INTRODUCTION

## 1.1 Introduction

Transport plays an important role in daily life because people depend on buses and other public transport services to move between towns, workplaces, schools, and business centres. In many transport environments, ticketing is still handled manually or semi-manually. A passenger may have to visit a station, call an operator, pay in cash, or depend on printed proof of payment. These methods can create delays, poor record keeping, fraud, and uncertainty for both passengers and transport companies.

SecureMove is a digital transport ticketing system designed to make bus travel booking more secure, traceable, and convenient. The system allows passengers to create accounts, search available routes, reserve bookings, make payments, and receive QR-based tickets. It also provides role-based dashboards for transport company administrators, drivers, conductors, and system administrators.

The project was implemented using Flutter for the client application and Node.js/Express with PostgreSQL for the backend. The system includes mobile money support, secure QR ticket signing, conductor scanning, and audit logging.

## 1.2 Background

Manual bus ticketing systems commonly depend on paper receipts, handwritten manifests, or disconnected payment records. These systems are vulnerable to loss, duplication, ticket reuse, and human error. Transport companies may also lack real-time information about bookings, revenue, route performance, and ticket validation results.

Digital ticketing improves the process by storing bookings in a central database and issuing electronic tickets. However, a digital ticketing system must also be secure. If a QR code can be copied or forged easily, the system may still suffer from fraud. SecureMove addresses this by generating signed QR payloads for paid tickets and validating them through a conductor workspace before passengers board.

## 1.3 Problem Statement

The current bus ticketing process in many environments is inefficient, difficult to monitor, and vulnerable to fraud. Passengers may not have a simple way to compare route options or receive a digital ticket immediately after payment. Transport operators may struggle to manage routes, drivers, schedules, payments, and ticket verification from one platform. Conductors may also lack a reliable method for identifying fake, expired, reused, or wrong-trip tickets.

Therefore, there is a need for a secure digital bus ticketing platform that supports online booking, payment processing, role-based transport management, QR ticket generation, and reliable ticket verification.

## 1.4 Aim

The aim of this project is to design and develop SecureMove, a secure digital bus ticketing and QR verification system that improves ticket booking, payment tracking, and passenger boarding verification.

## 1.5 Objectives

- To develop a Flutter application that allows passengers to search routes, reserve trips, pay for bookings, and view tickets.
- To implement a backend API for authentication, route schedules, bookings, payments, tickets, and role-based management.
- To generate secure QR tickets after successful payment.
- To provide a conductor scanner for validating signed tickets during boarding.
- To support company, driver, conductor, and super-administrator workspaces.
- To store booking, payment, scan, and audit information in a PostgreSQL database.
- To reduce ticket fraud through signed QR payloads, replay detection, scan logs, and fraud alerts.

## 1.6 Project Scope

SecureMove covers the main processes involved in digital bus ticketing. These include passenger registration and login, route searching, booking reservation, payment initiation, ticket generation, ticket display, booking history, company management, driver management, conductor scanning, and super-admin monitoring.

The system supports mobile money workflows through mock, live, and Lenco-style collection modes depending on environment configuration. The project does not include full production deployment hardening, advanced financial reconciliation, or integration with every possible transport operator payment provider.

## 1.7 Project Justification

The project is justified because public transport ticketing benefits from digitization, traceability, and fraud prevention. SecureMove reduces dependence on paper tickets, improves payment tracking, and gives different users access to role-specific tools. Passengers gain convenience, while companies and administrators gain better operational visibility. Conductors gain a practical scanning workflow that can identify invalid, expired, reused, or wrong-trip tickets.

## 1.8 Summary

This chapter introduced the SecureMove project, described the problem being addressed, and outlined the aim, objectives, scope, and justification. The next chapter reviews related systems and concepts that influenced the project design.

# CHAPTER 2: LITERATURE REVIEW

## 2.1 Introduction

This chapter reviews existing ticketing approaches and technologies relevant to SecureMove. The review focuses on manual ticketing, online transport booking platforms, QR-based ticketing, mobile money payments, and role-based transport management.

## 2.2 Related Literature

Digital ticketing systems replace physical tickets with electronic records that can be stored on a phone or retrieved from a server. Such systems reduce printing costs and improve access to transaction history. In public transport, digital ticketing also improves passenger flow because tickets can be checked quickly using QR codes or barcodes.

QR codes are widely used because they are easy to generate and scan using phone cameras. However, a QR code is only secure if the data inside it is protected. A plain text booking reference can be copied and reused. A signed payload, such as a JWT signed with a server-side secret, makes forgery more difficult because the scanner can confirm that the ticket was produced by the legitimate backend.

Mobile money is important in the Zambian context because many users rely on mobile wallets instead of bank cards. A transport ticketing system should therefore support local payment habits as the primary digital payment option.

## 2.3 Review of Existing or Current Systems

### 2.3.1 Manual Bus Ticketing

Manual ticketing uses paper receipts, notebooks, and direct cash payments. It is easy to start but difficult to audit. Records can be lost, forged, or duplicated. It also provides limited real-time information to transport company owners.

### 2.3.2 Online Booking Websites

Some transport operators provide websites for route search and booking. These systems improve convenience but may not always support conductor-side validation or real-time scan logs. They may also focus only on passenger booking and not on company, driver, and administrator workflows.

### 2.3.3 QR Ticketing Systems

QR ticketing systems allow passengers to present a code at boarding. The effectiveness of the system depends on how the QR code is generated and verified. SecureMove improves this by signing ticket payloads, checking trip assignment, tracking scan events, and flagging possible fraud.

### 2.3.4 Mobile Money Payment Systems

Mobile money services allow customers to approve payments from their phones. In a ticketing context, mobile money reduces dependence on cash and can link payment confirmation directly to ticket issuance. SecureMove includes mobile money initiation, status polling, webhook-oriented fulfillment, and mock mode for development.

## 2.4 Comparison of Reviewed Systems

| System Type | Strengths | Weaknesses | SecureMove Improvement |
| --- | --- | --- | --- |
| Manual ticketing | Simple and familiar | Poor traceability, fraud risk, slow reporting | Digital records and QR verification |
| Basic online booking | Convenient for passengers | Often limited management tools | Passenger, company, driver, conductor, and admin roles |
| Plain QR tickets | Fast to scan | Easy to copy if unsigned | Signed QR payloads and replay checks |
| Cash payments | Widely accepted | Hard to reconcile | Mobile money payment records |

## 2.5 Proposed System

SecureMove proposes a centralized digital ticketing platform with multiple user roles. Passengers interact with the Flutter application to search routes, book travel, pay, and view tickets. Company administrators manage operational data such as drivers, schedules, tickets, and dashboards. Drivers view assigned trips and profile information. Conductors scan QR tickets and report duplicate scan situations. Super administrators monitor companies, users, transactions, security logs, scan logs, reports, and analytics.

## 2.6 Summary

The literature review shows that digital transport ticketing is valuable, but it must include security, payment integration, and operational management. SecureMove combines these features into one project.

# CHAPTER 3: RESEARCH METHODOLOGY

## 3.1 Introduction

This chapter explains the methodology followed during the project. It describes the development approach, tools, technologies, and reasons for selecting them.

## 3.2 Selected Methodology

The project followed a waterfall-inspired development model. The main phases were requirements analysis, system design, implementation, testing, and documentation. Although some iteration occurred during development, the overall structure was sequential because the project needed clear deliverables for an academic capstone.

## 3.3 Phases of the Methodology

### 3.3.1 Requirements Gathering

The requirements were identified by considering problems in manual bus ticketing and by defining the needs of passengers, company administrators, drivers, conductors, and system administrators.

### 3.3.2 System Design

The system was designed as a client-server application. Flutter was selected for the front end because it supports multiple platforms from one codebase. Node.js and Express were selected for the backend API. PostgreSQL was selected for structured data storage.

### 3.3.3 Implementation

The Flutter application was implemented with screens and services for authentication, route listing, booking, payment, ticket display, company management, driver workspace, conductor scanning, and administration. The backend was implemented using Express routes, controllers, middleware, services, and database migrations.

### 3.3.4 Testing

Testing focused on functional workflows such as registration, login, route search, booking reservation, payment initiation, ticket generation, QR scanning, and role-based access. Payment flows were tested using mock mobile money configuration.

### 3.3.5 Documentation

Documentation was prepared by reviewing the final system files and organizing the report according to the academic project report structure.

## 3.4 Technologies and Frameworks Used

| Technology | Use in SecureMove |
| --- | --- |
| Flutter | Cross-platform front-end application |
| Dart | Flutter application programming language |
| Node.js | Backend runtime environment |
| Express.js | REST API framework |
| PostgreSQL | Relational database |
| JWT | Authentication tokens and signed ticket payloads |
| bcrypt | Password hashing |
| Flutter Secure Storage | Secure client-side token storage |
| Mobile Scanner | QR scanning in conductor workflow |
| qr_flutter and qrcode | QR generation/display support |
| Mobile money services | MTN, Airtel, Lenco, and mock payment flows |
| Socket.IO | Real-time fraud alert broadcasting support |
| Render | Backend deployment target |

## 3.5 Justification of Tools

Flutter was chosen because it provides a single codebase for Android, iOS, web, and desktop targets. This is suitable for a project where passengers, company staff, and conductors may use different devices.

Node.js and Express were chosen because they allow fast development of REST APIs and integrate well with payment services, JSON Web Tokens, and PostgreSQL. PostgreSQL was selected because the system depends on structured relationships between users, companies, routes, trips, bookings, tickets, payments, and scan events.

JWT was used for authentication because it allows the backend to issue a token containing user identity and role information. Signed JWT payloads were also used for ticket QR codes so that the conductor scanner can detect tampered tickets.

## 3.6 Summary

This chapter described the development methodology and the technologies used. The next chapter presents the system analysis and design.

# CHAPTER 4: SYSTEM ANALYSIS AND DESIGN

## 4.1 Introduction

This chapter presents the functional and non-functional requirements, use case analysis, data flow, architecture, and database design of SecureMove.

## 4.2 System Analysis

### 4.2.1 Functional Requirements

| Requirement | Description |
| --- | --- |
| User registration | A new passenger can create an account using name, email, and password. |
| User login | A registered user can log in and receive an authentication token. |
| Role-based routing | Users are directed to screens according to their assigned role. |
| Route search | Passengers can search available bus schedules by origin and destination. |
| Booking reservation | A passenger can reserve a booking for a trip or schedule. |
| Payment processing | A passenger can pay using mobile money. |
| Ticket generation | A paid booking produces a ticket with a signed QR payload. |
| My bookings | Passengers can view previous bookings and tickets. |
| Company dashboard | Company users can view bookings, drivers, schedules, and tickets. |
| Driver workspace | Drivers can view their profile, trips, and notifications. |
| Conductor scanner | Conductors can scan tickets and receive validation results. |
| Super admin dashboard | Super admins can monitor companies, users, transactions, analytics, and logs. |
| Audit logging | Important security and scan events are stored for review. |

### 4.2.2 Non-Functional Requirements

| Requirement | Description |
| --- | --- |
| Security | Passwords must be hashed and protected routes must require valid JWTs. |
| Usability | Interfaces should be understandable for passengers and transport staff. |
| Reliability | Payment fulfillment and ticket creation should be idempotent where possible. |
| Maintainability | Code should be separated into screens, services, routes, controllers, and middleware. |
| Scalability | The backend and database design should allow more companies, users, and trips. |
| Portability | The Flutter app should support multiple device targets. |
| Auditability | Login attempts, ticket scans, and fraud alerts should be traceable. |

## 4.3 Use Case Analysis

### 4.3.1 Passenger Use Case

The passenger registers or logs in, searches for a route, selects a bus, chooses a travel date and number of tickets, reserves a booking, pays, and receives a QR ticket. The passenger can later open the ticket or view booking history.

### 4.3.2 Company Administrator Use Case

The company administrator manages company-related operational information such as drivers, schedules, and ticket records. The company dashboard provides statistics and management actions.

### 4.3.3 Driver Use Case

The driver logs in to view assigned trips, update profile information, upload a profile photo, and review trip-related information.

### 4.3.4 Conductor Use Case

The conductor logs in to view the assigned trip, scan passenger QR tickets, receive validation results, and report duplicate scan issues.

### 4.3.5 Super Administrator Use Case

The super administrator manages companies and users, approves companies, reviews transactions, monitors security logs, checks scan logs, and views reports and analytics.

## 4.4 Data Flow Overview

The main passenger booking flow is as follows:

1. The passenger logs in and receives a JWT.
2. The app requests route schedules from the backend.
3. The passenger selects a bus and reserves a booking.
4. The payment process is initiated using mobile money.
5. When payment succeeds, the backend marks the booking as paid.
6. The backend creates a ticket and signs the QR payload.
7. The passenger views the ticket in the Flutter app.
8. The conductor scans the QR code during boarding.
9. The backend verifies the signature, trip, ticket status, and replay conditions.
10. The scan result and audit event are stored.

## 4.5 System Architecture

SecureMove uses a three-layer architecture:

- Presentation layer: Flutter screens and widgets.
- Application/API layer: Node.js Express routes, controllers, middleware, and services.
- Data layer: PostgreSQL tables and migrations.

The Flutter app communicates with the backend through REST endpoints. Authentication tokens are stored using Flutter Secure Storage. The backend protects sensitive routes using authentication and role-checking middleware. PostgreSQL stores structured records such as users, companies, route schedules, drivers, buses, trips, bookings, tickets, payments, audit logs, conductors, scan events, and fraud alerts.

## 4.6 Component Descriptions

### 4.6.1 Flutter Front End

The Flutter front end contains screens for authentication, passenger home, bus listing, payment, ticket display, bookings, profile, company dashboards, management hubs, driver workspace, conductor scanner, security activity, and super admin functions. Shared widgets and theme files provide consistent styling.

### 4.6.2 Authentication Service

The authentication service handles registration, login, logout, token storage, session expiry, saved email loading, and profile fetching. The app expires a session when it goes into the background and returns the user to login on resume.

### 4.6.3 Booking Service

The booking service communicates with backend booking endpoints to reserve bookings, fetch bookings, cancel bookings, and retrieve tickets for a booking.

### 4.6.4 Payment Services

SecureMove includes mobile money through backend payment endpoints. Mobile money supports configuration checks, payment initiation, status polling, mock settlement, and live provider-oriented flows.

### 4.6.5 Backend API

The backend exposes endpoints for authentication, bookings, companies, company role management, conductors, drivers, payments, routes, security, tickets, and super-admin operations.

### 4.6.6 Ticket Verification Service

The ticket verification utility verifies signed QR payloads, detects fake signatures, checks replay attempts, validates trip assignment, checks expiry and boarding windows, confirms payment status, marks tickets as used, and logs scan results.

### 4.6.7 Database

The database contains normalized tables for users, companies, audit logs, route schedules, drivers, buses, trips, bookings, tickets, payments, conductors, ticket scan events, fraud alerts, and driver notifications. Indexes are used for common search and reporting fields.

## 4.7 Security Design

SecureMove uses several security controls:

- Passwords are hashed using bcrypt before storage.
- JWTs are used to authenticate API requests.
- Role-based middleware limits access to company, driver, conductor, and super-admin features.
- Tickets are represented by signed JWT payloads rather than plain text codes.
- Ticket scans are logged with result status, device information, IP address, QR hash, and fraud flag.
- Replay attempts and fake signatures can trigger fraud alerts.
- Audit logs record login, registration, and ticket scan events.

## 4.8 Database Design Summary

The central database entities include:

- Users: stores account identity, email, password hash, role, and company scope.
- Companies: stores transport company records and approval status.
- Route schedules: stores origin, destination, departure time, price, duration, and features.
- Buses: stores bus registration, capacity, type, features, and active status.
- Drivers and conductors: store operational staff details.
- Trips: stores scheduled trip instances.
- Bookings: stores passenger reservations and payment state.
- Tickets: stores generated ticket numbers, passenger names, seats, QR payloads, and verification state.
- Payments: stores mobile money payment records.
- Audit logs and scan events: store security and verification history.
- Fraud alerts: store suspected fake or replayed scan attempts.

## 4.9 Summary

This chapter analyzed and designed the SecureMove system. It described requirements, use cases, architecture, components, security controls, and the database structure.

# CHAPTER 5: RESULT ANALYSIS

## 5.1 Introduction

This chapter discusses the implemented system and the results of functional testing. The final SecureMove system includes passenger ticketing, management dashboards, payment flows, and QR verification features.

## 5.2 Environment Description

The project was developed in a Flutter and Node.js environment. The client application is located in the `securemove` folder and the backend is located in the `securemove-backend` folder. The backend uses PostgreSQL and environment variables for configuration such as database connection, JWT secret, ticket secret, mobile money mode, and payment provider credentials.

The app defaults to the deployed Render backend URL but can be configured with build-time variables such as `API_BASE_URL` and `PAYMENT_API_BASE_URL`.

## 5.3 Implemented Features

### 5.3.1 Authentication

Users can register and log in. Passwords are hashed before storage and login returns a JWT. The token contains role information so the app can direct the user to the correct workspace.

### 5.3.2 Passenger Booking

Passengers can search available routes, compare bus options, select a trip, choose a travel date, adjust ticket count, and reserve a booking.

### 5.3.3 Payment

The payment screen supports mobile money paths. Mobile money can run in mock, live, or Lenco mode depending on backend configuration.

### 5.3.4 Ticket Generation

When a payment succeeds, the backend marks the booking as paid and creates a ticket. The ticket includes a ticket number, seat number, passenger name, status, and signed QR payload.

### 5.3.5 QR Verification

The conductor scanner verifies QR payloads through the backend. It can return results such as valid, fake, already used, wrong trip, expired, scheduled later, unpaid, or invalid.

### 5.3.6 Management Dashboards

Company and super-admin dashboards provide visibility into companies, users, bookings, transactions, scan logs, security logs, reports, and analytics.

## 5.4 Unit Testing

The project used a practical testing approach focused on important system functions. Testing covered authentication, booking reservation, payment initiation, ticket retrieval, and ticket verification. The backend services were designed with validation and error handling to reduce invalid states.

## 5.5 System Testing

System testing was performed by following complete workflows from login to ticket scanning. The aim was to confirm that the different system modules work together as expected.

| Test Case | Input/Action | Expected Result | Status |
| --- | --- | --- | --- |
| Register user | Name, email, password | User account is created | Passed |
| Login user | Valid email and password | JWT token is returned | Passed |
| Login with wrong password | Invalid password | Error response is returned and audit event is recorded | Passed |
| Search route | Origin and destination | Matching active schedules are returned | Passed |
| Reserve booking | Trip/schedule and amount | Booking reference is created | Passed |
| Initiate mobile money | Booking, provider, phone, amount | Pending payment is created | Passed |
| Mock payment settlement | Poll payment status | Payment becomes successful and ticket is issued | Passed |
| Retrieve ticket | Paid booking ID | Ticket data and signed QR are returned | Passed |
| Scan valid ticket | Signed QR for assigned trip | Passenger may board | Passed |
| Scan fake QR | Unsigned or tampered QR | Fraud warning is returned | Passed |
| Scan same ticket twice | Already used ticket | Already used response is returned | Passed |
| Scan wrong trip ticket | Valid ticket for different trip | Wrong trip response is returned | Passed |
| View admin dashboard | Super-admin user | System statistics are returned | Passed |

## 5.6 Test Scenarios

### Test Scenario 1: Successful Passenger Booking and Ticket Issue

The passenger logs in, searches for a route, reserves a booking, pays through mobile money, and receives a signed QR ticket. The expected result is that the booking status becomes paid and the ticket becomes available in the app.

### Test Scenario 2: Failed Login

The user enters an incorrect password. The backend rejects the login, records an audit event, and does not issue a token.

### Test Scenario 3: Fake QR Scan

The conductor scans a QR code that was not signed by SecureMove. The backend identifies the invalid signature, logs the scan, and can trigger a fraud alert.

### Test Scenario 4: Duplicate Ticket Scan

The conductor scans a ticket that has already been used. The backend returns an already-used result and records the event for later review.

### Test Scenario 5: Wrong Trip Scan

The conductor scans a valid ticket that belongs to a different trip. The backend rejects boarding and shows route details so the conductor can identify the problem.

## 5.7 Result Discussion

The results show that SecureMove meets the core project objectives. Passengers can move from route discovery to payment and ticket viewing. Transport staff can manage important operational workflows. The conductor verification process improves security because it validates the signed ticket, trip assignment, ticket status, boarding time, and scan history.

Some areas still require further production work, such as broader automated testing, final payment provider certification, stronger deployment monitoring, and more detailed financial reporting.

## 5.8 Summary

This chapter presented the implemented features and testing results. SecureMove successfully demonstrates secure digital bus ticketing with QR verification.

# CHAPTER 6: PROJECT MANAGEMENT

## 6.1 Introduction

This chapter presents the project management approach, risks, quality management, effort estimation, budget, and work plan.

## 6.2 Risk and Quality Management

Risk management involved identifying likely problems and preparing mitigation strategies. Quality management focused on modular code structure, validation, error handling, and testing important workflows.

## 6.3 Risk Register

| Risk | Impact | Probability | Mitigation |
| --- | --- | --- | --- |
| Payment provider failure | High | Medium | Provide mock mode and clear error messages |
| Weak QR security | High | Medium | Use signed QR payloads and server-side verification |
| Token misuse | Medium | Medium | Use JWT expiry and protected routes |
| Database inconsistency | High | Low | Use constraints, indexes, and idempotent fulfillment |
| Poor usability | Medium | Medium | Use clear screens and role-specific workflows |
| Network failure | Medium | Medium | Display retry/error messages |
| Scope creep | Medium | Medium | Focus on core ticketing, payment, and verification |

## 6.4 Quality Management

The project applied the following quality practices:

- Separation of Flutter screens, services, widgets, and theme files.
- Separation of backend routes, controllers, services, middleware, and migrations.
- Input validation on API endpoints.
- Clear error responses for failed actions.
- Database constraints for unique and required records.
- Audit logs for important security events.
- Manual end-to-end testing of major workflows.

## 6.5 Effort Costing Model

A simplified COCOMO-style effort estimate was used for planning. The project is a small-to-medium academic software project with multiple modules. The main effort areas were requirements analysis, UI design, backend API development, database design, payment integration, QR verification, testing, and documentation.

Estimated effort distribution:

| Phase | Estimated Effort |
| --- | --- |
| Requirements and analysis | 10% |
| System design | 15% |
| Frontend implementation | 25% |
| Backend implementation | 25% |
| Database and migrations | 10% |
| Testing and debugging | 10% |
| Documentation | 5% |

## 6.6 Budget

| Item | Estimated Cost |
| --- | --- |
| Development laptop | Existing resource |
| Internet/data | Variable |
| Hosting/testing backend | Low to medium depending on deployment plan |
| Database hosting | Low to medium depending on provider |
| Payment provider testing | Test mode/no real charge |
| Documentation and printing | Variable |

The project was developed mostly using open-source tools, which reduced the overall cost.

## 6.7 Scheduling and Work Plan

| Activity | Description |
| --- | --- |
| Week 1-2 | Requirements gathering and problem definition |
| Week 3-4 | System design and database planning |
| Week 5-8 | Flutter passenger workflow implementation |
| Week 9-11 | Backend API and database implementation |
| Week 12-13 | Payment and ticket generation implementation |
| Week 14-15 | Conductor, driver, company, and admin workspaces |
| Week 16 | Testing, debugging, and documentation |

## 6.8 Summary

This chapter described the management of the SecureMove project, including risks, quality control, effort estimation, budget, and schedule.

# CHAPTER 7: CRITICAL EVALUATION

## 7.1 Introduction

This chapter evaluates the project, explains why it was undertaken, describes learning outcomes, identifies challenges, and suggests future work.

## 7.2 Reason for Undertaking the Project

The project was undertaken to solve practical problems in bus ticketing. Manual processes are slow and can be unreliable. A digital solution provides convenience for passengers and better control for transport companies. The project also allowed the application of software engineering concepts such as API design, mobile application development, database design, authentication, payment integration, and security logging.

## 7.3 Main Learning Outcomes

The project provided experience in:

- Building a Flutter application with multiple role-based screens.
- Connecting Flutter to a REST backend using HTTP services.
- Designing a PostgreSQL database for a real-world workflow.
- Implementing authentication with password hashing and JWTs.
- Handling payment initiation and status polling.
- Generating and verifying signed QR ticket payloads.
- Designing dashboards for different user roles.
- Logging security events and scan outcomes.
- Structuring a full-stack project for maintainability.

## 7.4 Challenges Encountered

One challenge was coordinating payment completion with ticket generation. The system needed to ensure that a ticket is created only after successful payment and that repeated polling or webhooks do not create duplicate tickets. This was addressed through idempotent fulfillment logic.

Another challenge was QR ticket security. A simple QR code would be easy to copy or forge, so the system uses signed payloads and server-side verification.

Role management was also challenging because different users require different permissions and screens. The project addressed this through role IDs, role-based middleware, and separate Flutter workspaces.

Mobile payment integration introduced complexity because provider responses may be delayed, failed, or pending. The system handles this using status polling, mock mode, provider-specific services, and user-friendly error messages.

## 7.5 Limitations

The project has some limitations:

- Automated test coverage is limited compared to a production system.
- Payment providers require final production credentials and certification before real deployment.
- The current ticket fulfillment issues one automatic seat in some flows.
- Advanced financial reconciliation and refund management are not fully implemented.
- Offline conductor scanning is not fully supported because server validation is required.

## 7.6 Future Work

Future improvements may include:

- Full automated unit, widget, and integration testing.
- Advanced seat selection and multi-seat ticket generation.
- Offline-capable conductor scanning with later synchronization.
- Refund and cancellation workflows for paid bookings.
- SMS or email ticket delivery.
- More detailed analytics for route performance and revenue.
- Production monitoring and alerting.
- Stronger admin controls for fraud investigation and account recovery.

## 7.7 Summary

SecureMove achieved its main objectives and demonstrated a working secure ticketing platform. The project also revealed areas where additional production-level improvements can be added.

# CHAPTER 8: CONCLUSION

## 8.1 Introduction

This chapter concludes the project report by summarizing the contribution and final outcome of SecureMove.

## 8.2 Research Contribution

SecureMove contributes a practical full-stack solution for digital bus ticketing. It combines passenger booking, mobile money payment, signed QR ticket generation, conductor validation, company management, driver workspaces, super-admin monitoring, audit logging, and fraud alert support.

The project demonstrates how secure ticket verification can be implemented using signed QR payloads and backend validation. It also demonstrates how role-based access can support different transport stakeholders in one system.

## 8.3 Conclusion

The SecureMove project successfully addresses the problem of insecure and inefficient manual bus ticketing. The system provides passengers with a convenient booking and ticketing experience, while giving transport operators and administrators better control over routes, bookings, payments, and ticket verification. The conductor scanning workflow strengthens boarding security by detecting fake, reused, expired, unpaid, and wrong-trip tickets.

Although further production hardening is required, the project provides a strong foundation for a secure digital transport ticketing platform.

# REFERENCES

Flutter Documentation. Flutter: Build apps for any screen.

Dart Documentation. Dart programming language documentation.

Express.js Documentation. Fast, unopinionated, minimalist web framework for Node.js.

PostgreSQL Documentation. The world's most advanced open source relational database.


JSON Web Token Documentation. Introduction to JSON Web Tokens.

Node.js Documentation. Node.js runtime documentation.

OWASP Foundation. Authentication, session management, and application security guidance.

# APPENDIX A: MAIN PROJECT FILES REVIEWED

Flutter application:

- `lib/main.dart`
- `lib/auth_screens.dart`
- `lib/auth_service.dart`
- `lib/home_screen.dart`
- `lib/bus_list_screen.dart`
- `lib/payment_screen.dart`
- `lib/ticket_screen.dart`
- `lib/my_bookings_screen.dart`
- `lib/company_dashboard_screen.dart`
- `lib/management_hub_screen.dart`
- `lib/driver_workspace_screen.dart`
- `lib/screens/conductor/conductor_scanner_screen.dart`
- `lib/screens/super_admin/admin_dashboard_screen.dart`

Backend application:

- `server.js`
- `routes/auth.js`
- `routes/bookings.js`
- `routes/payments.js`
- `routes/tickets.js`
- `routes/conductorRoutes.js`
- `routes/companyRoutes.js`
- `routes/superAdminRoutes.js`
- `controllers/conductorController.js`
- `controllers/superAdminController.js`
- `services/bookingFulfillment.js`
- `utils/ticketVerifier.js`
- `migrations/001_foundation.sql`
- `migrations/003_role_workspaces.sql`
- `migrations/004_secure_conductor_scans.sql`
