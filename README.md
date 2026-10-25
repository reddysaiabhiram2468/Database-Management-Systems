# Database Management Systems – Airline Reservation & Flight Booking System

**DBMS Lab coursework by Reddy Sai Abhiram**

The database manages flight schedules, the aircraft fleet, passenger profiles, bookings (PNRs), seat assignments and payments for an airline. It is implemented in **MySQL 8.0** as the `airline_reservation` database.

## Earlier work

- [Identifying Tables for a Real-World Application.pdf](Identifying%20Tables%20for%20a%20Real-World%20Application.pdf): the proposed six-table design (Passengers, Airports, Flights, Bookings, Ticket_Details, Payments). Assignments 3–9 build on it.

## Assignment reports

| Assignment | Topic | PDF |
|:--:|---|---|
| 3 | Database design analysis: redundancy, anomalies, functional dependencies, normalization | [Assignment_3_Normalization.pdf](Assignment_3_Normalization.pdf) |
| 4 | Relational vs NoSQL databases: comparative report | [Assignment_4_RDBMS_vs_NoSQL.pdf](Assignment_4_RDBMS_vs_NoSQL.pdf) |
| 5 | Database creation and table implementation | [Assignment_5_Database_Creation.pdf](Assignment_5_Database_Creation.pdf) |
| 6 | Data integrity constraints | [Assignment_6_Integrity_Constraints.pdf](Assignment_6_Integrity_Constraints.pdf) |
| 7 | Sample data insertion | [Assignment_7_Sample_Data_Insertion.pdf](Assignment_7_Sample_Data_Insertion.pdf) |
| 8 | Basic SQL queries and aggregate functions | [Assignment_8_Basic_SQL_Queries.pdf](Assignment_8_Basic_SQL_Queries.pdf) |
| 9 | Advanced SQL: joins and subqueries | [Assignment_9_Joins_and_Subqueries.pdf](Assignment_9_Joins_and_Subqueries.pdf) |

## Finalized schema (9 tables + 2 views)

`airports`, `aircraft`, `travel_classes`, `routes`, `flights`, `passengers`, `bookings`, `ticket_details`, `payments`

Views: `v_booking_totals` (booking total and amount paid) and `v_flight_occupancy` (seats sold and load factor).

## Running the SQL

You need MySQL 8.0.16 or newer, because CHECK constraints are enforced from that version. Run the scripts in this order:

1. `sql/01_create_database.sql`: database, tables, keys and views (Assignment 5)
2. `sql/02_constraints.sql`: UNIQUE, CHECK and DEFAULT constraints, plus triggers (Assignment 6)
3. `sql/03_constraint_tests.sql`: the Assignment 6 test cases. Run it with `--force`, because 24 statements are meant to fail.
4. `sql/04_sample_data.sql`: 860 rows of sample data (Assignment 7)
5. `sql/05_basic_queries.sql`: Assignment 8 queries
6. `sql/06_advanced_queries.sql`: Assignment 9 reports

The airline "SkyWings", its flight numbers and aircraft registrations, and all passenger details are fictitious. Airports are real.
