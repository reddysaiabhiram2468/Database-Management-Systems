/* Airline Reservation - Assignment 6 : constraint test cases
   Run on the EMPTY database after 01 and 02 (before 04_sample_data.sql), with --force:
   statements marked 'expect error' are meant to fail. */
USE airline_reservation;

-- fixture: Airports, a tiny test aircraft (2 economy seats, 1 business seat) and two travel classes
INSERT INTO airports (airport_code, airport_name, city) VALUES
    ('HYD', 'Rajiv Gandhi International Airport', 'Hyderabad'),
    ('DEL', 'Indira Gandhi International Airport', 'New Delhi');
INSERT INTO aircraft (aircraft_id, registration, model, economy_seats, business_seats, in_service_since)
VALUES (1, 'VT-TST', 'Test Trainer', 2, 1, '2024-01-01');
INSERT INTO travel_classes VALUES ('EC', 'Economy', 1.00, 15), ('BU', 'Business', 3.20, 35);
SELECT airport_code, city, country FROM airports;
SELECT aircraft_id, registration, economy_seats, premium_seats, business_seats, first_seats, status FROM aircraft;

-- fixture: A route and its flight on 1 December 2026 (flight_status uses DEFAULT)
INSERT INTO routes (route_id, flight_number, origin_code, destination_code, scheduled_departure, duration_min, distance_km)
VALUES (1, 'TS101', 'HYD', 'DEL', '06:00', 130, 1265);
INSERT INTO flights (flight_id, route_id, aircraft_id, departure_time, arrival_time, base_price)
VALUES (1, 1, 1, '2026-12-01 06:00', '2026-12-01 08:10', 5000.00);
SELECT flight_id, route_id, departure_time, departure_date, base_price, flight_status FROM flights;

-- fixture: Passengers (nationality uses DEFAULT) and a booking (booking_date and status use DEFAULT)
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, passport_number, date_of_birth) VALUES
    (1, 'Test',   'Traveller', 'test.traveller@example.com', '+919876543210', 'M1234567', '1995-05-05'),
    (2, 'Second', 'Traveller', 'second.trav@example.com',   '+919123456780', 'N7654321', '1990-01-01'),
    (3, 'Third',  'Traveller', 'third.trav@example.com',    '+919000000003', 'P1112223', '2010-09-09');
INSERT INTO bookings (booking_id, passenger_id, booking_reference) VALUES (1, 1, 'TEST01');
SELECT passenger_id, first_name, nationality FROM passengers;
SELECT booking_id, passenger_id, booking_reference, booking_date, status FROM bookings;

-- TC-01 [Entity] Primary key: an airport code can exist only once  (expect error)
INSERT INTO airports (airport_code, airport_name, city) VALUES ('HYD', 'Duplicate', 'Hyderabad');

-- TC-02 [Entity] NOT NULL: e-mail is mandatory  (expect error)
INSERT INTO passengers (first_name, last_name, phone, passport_number, date_of_birth)
VALUES ('No', 'Email', '+919000000009', 'Z9999999', '2000-01-01');

-- TC-03 [Unique] Two passengers cannot share an e-mail  (expect error)
INSERT INTO passengers (first_name, last_name, email, phone, passport_number, date_of_birth)
VALUES ('Copy', 'Cat', 'test.traveller@example.com', '+919000000004', 'K4445556', '1999-01-01');

-- TC-04 [Unique] Same passport number and same nationality is rejected  (expect error)
INSERT INTO passengers (first_name, last_name, email, phone, passport_number, date_of_birth)
VALUES ('Fake', 'Passport', 'fake@example.com', '+919000000005', 'M1234567', '1980-01-01');

-- TC-05 [Unique] …but the same number issued by another country is accepted
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, passport_number, nationality, date_of_birth)
VALUES (4, 'John', 'Smith', 'john.smith@example.com', '+447700900123', 'M1234567', 'British', '1985-03-03');
SELECT passenger_id, first_name, passport_number, nationality FROM passengers WHERE passport_number = 'M1234567';

-- TC-06 [Unique] A flight number identifies one route  (expect error)
INSERT INTO routes (flight_number, origin_code, destination_code, scheduled_departure, duration_min, distance_km)
VALUES ('TS101', 'DEL', 'HYD', '10:00', 135, 1265);

-- TC-07 [Unique (generated)] A route operates at most once per day  (expect error)
INSERT INTO flights (route_id, aircraft_id, departure_time, arrival_time, base_price)
VALUES (1, 1, '2026-12-01 18:00', '2026-12-01 20:10', 4500);

-- TC-08 [Domain] CHECK: airport codes are three capital letters  (expect error)
INSERT INTO airports (airport_code, airport_name, city) VALUES ('hy1', 'Bad Code', 'Nowhere');

-- TC-09 [Domain] CHECK: origin and destination must differ  (expect error)
INSERT INTO routes (flight_number, origin_code, destination_code, scheduled_departure, duration_min, distance_km)
VALUES ('TS999', 'HYD', 'HYD', '09:00', 60, 10);

-- TC-10 [Domain] CHECK: a flight cannot arrive before it departs  (expect error)
UPDATE flights SET arrival_time = '2026-12-01 05:00' WHERE flight_id = 1;

-- TC-11 [Domain] CHECK: passport number format  (expect error)
UPDATE passengers SET passport_number = 'AB-12' WHERE passenger_id = 2;

-- TC-12 [Domain] ENUM: unknown flight status is rejected  (expect error)
UPDATE flights SET flight_status = 'Boarding' WHERE flight_id = 1;

-- TC-13 [Referential] FK: a ticket must refer to an existing flight  (expect error)
INSERT INTO ticket_details (booking_id, flight_id, passenger_id, seat_number, fare)
VALUES (1, 99, 1, '10A', 5000);

-- TC-14 [Default + trigger] Sell a seat giving only booking, flight, traveller and seat
INSERT INTO ticket_details (ticket_id, booking_id, flight_id, passenger_id, seat_number)
VALUES (1, 1, 1, 1, '12A');
SELECT ticket_id, passenger_id, class_code, seat_number, fare, ticket_status, active_seat
FROM ticket_details;

-- TC-15 [Domain] CHECK: seat numbers look like 12A  (expect error)
INSERT INTO ticket_details (booking_id, flight_id, passenger_id, seat_number)
VALUES (1, 1, 2, 'Z9');

-- TC-16 [Unique (generated)] No double-booking: seat 12A is already taken  (expect error)
INSERT INTO ticket_details (booking_id, flight_id, passenger_id, seat_number)
VALUES (1, 1, 2, '12A');

-- TC-17 [Unique (generated)] A traveller cannot hold two seats on the same flight  (expect error)
INSERT INTO ticket_details (booking_id, flight_id, passenger_id, seat_number)
VALUES (1, 1, 1, '12B');

-- TC-18 [Trigger] Cabin capacity: the second economy seat sells, the third is refused  (expect error)
INSERT INTO ticket_details (ticket_id, booking_id, flight_id, passenger_id, seat_number)
VALUES (2, 1, 1, 2, '12B');
INSERT INTO ticket_details (booking_id, flight_id, passenger_id, seat_number)
VALUES (1, 1, 3, '12C');

-- TC-19 [Accepted] Cancelling a ticket releases its seat and capacity
UPDATE ticket_details SET ticket_status = 'Cancelled' WHERE ticket_id = 2;
INSERT INTO ticket_details (ticket_id, booking_id, flight_id, passenger_id, seat_number)
VALUES (3, 1, 1, 3, '12B');
SELECT ticket_id, passenger_id, seat_number, ticket_status, active_seat FROM ticket_details;

-- TC-20 [Trigger] Business fare is computed as base price × 3.20 when no fare is given
INSERT INTO ticket_details (ticket_id, booking_id, flight_id, passenger_id, class_code, seat_number)
VALUES (4, 1, 1, 2, 'BU', '1A');
SELECT ticket_id, passenger_id, class_code, seat_number, fare FROM ticket_details WHERE ticket_id = 4;

-- TC-21 [Unique (generated)] A failed attempt and one success are allowed; a second success is not  (expect error)
INSERT INTO payments (booking_id, amount, payment_method, payment_status, transaction_ref)
VALUES (1, 26000, 'Credit Card', 'Failed',  'TXN0001'),
       (1, 26000, 'UPI',         'Success', 'TXN0002');
SELECT payment_id, amount, payment_method, payment_status, transaction_ref, success_booking FROM payments;
INSERT INTO payments (booking_id, amount, payment_method, payment_status, transaction_ref)
VALUES (1, 26000, 'UPI', 'Success', 'TXN0003');

-- TC-22 [Domain] CHECK: a payment amount must be positive  (expect error)
INSERT INTO payments (booking_id, amount, payment_method, payment_status, transaction_ref)
VALUES (1, 0, 'UPI', 'Failed', 'TXN0004');

-- TC-23 [Unique] Gateway transaction references are unique  (expect error)
INSERT INTO payments (booking_id, amount, payment_method, payment_status, transaction_ref)
VALUES (1, 100, 'UPI', 'Failed', 'TXN0001');

-- TC-24 [Trigger] Cancelling the flight cancels every live ticket on it
UPDATE flights SET flight_status = 'Cancelled' WHERE flight_id = 1;
SELECT ticket_id, passenger_id, seat_number, ticket_status FROM ticket_details;

-- TC-25 [Trigger] A cancelled flight is no longer open for booking  (expect error)
INSERT INTO ticket_details (booking_id, flight_id, passenger_id, seat_number)
VALUES (1, 1, 3, '14C');

-- TC-26 [Trigger] A cancelled booking cannot be paid  (expect error)
INSERT INTO bookings (booking_id, passenger_id, booking_reference, status) VALUES (2, 2, 'TEST02', 'Cancelled');
INSERT INTO payments (booking_id, amount, payment_method, payment_status, transaction_ref)
VALUES (2, 5000, 'UPI', 'Success', 'TXN0005');

-- TC-27 [Referential] RESTRICT: an airport used by a route cannot be deleted  (expect error)
DELETE FROM airports WHERE airport_code = 'HYD';

-- TC-28 [Referential] RESTRICT on update: an IATA code in use cannot be changed  (expect error)
UPDATE airports SET airport_code = 'HDD' WHERE airport_code = 'HYD';

-- TC-29 [Referential] RESTRICT: a passenger with bookings cannot be deleted  (expect error)
DELETE FROM passengers WHERE passenger_id = 1;

-- TC-30 [Referential] CASCADE: deleting a booking deletes its tickets and payments (rolled back)
START TRANSACTION;
DELETE FROM bookings WHERE booking_id = 1;
SELECT (SELECT COUNT(*) FROM ticket_details) AS tickets_left, (SELECT COUNT(*) FROM payments) AS payments_left;
ROLLBACK;

-- TC-31 [Referential] ON UPDATE CASCADE: renaming a class code updates its tickets (rolled back)
START TRANSACTION;
UPDATE travel_classes SET class_code = 'BZ' WHERE class_code = 'BU';
SELECT ticket_id, class_code FROM ticket_details WHERE ticket_id = 4;
ROLLBACK;

-- remove the fixture
DELETE FROM payments;   DELETE FROM ticket_details; DELETE FROM bookings;
DELETE FROM passengers; DELETE FROM flights;        DELETE FROM routes;
DELETE FROM aircraft;   DELETE FROM travel_classes; DELETE FROM airports;
SELECT (SELECT COUNT(*) FROM flights) AS flights, (SELECT COUNT(*) FROM ticket_details) AS tickets,
       (SELECT COUNT(*) FROM passengers) AS passengers;
