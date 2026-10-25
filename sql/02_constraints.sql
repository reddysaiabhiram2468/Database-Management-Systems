/* =====================================================================
   Airline Reservation & Flight Booking System
   Assignment 6 : integrity constraints (requires MySQL 8.0.16+)
   Primary and foreign keys were declared in 01_create_database.sql.
   This script adds, in order:
     A. UNIQUE constraints      B. CHECK constraints
     C. DEFAULT values          D. triggers for multi-table rules
   ===================================================================== */
USE airline_reservation;

/* ============================ A. UNIQUE ============================ */
ALTER TABLE aircraft       ADD CONSTRAINT uk_aircraft_registration UNIQUE (registration);
ALTER TABLE travel_classes ADD CONSTRAINT uk_class_name            UNIQUE (class_name);
ALTER TABLE routes         ADD CONSTRAINT uk_route_flight_number   UNIQUE (flight_number);
ALTER TABLE passengers     ADD CONSTRAINT uk_passenger_email       UNIQUE (email);
ALTER TABLE passengers     ADD CONSTRAINT uk_passenger_passport    UNIQUE (nationality, passport_number);
ALTER TABLE bookings       ADD CONSTRAINT uk_booking_reference     UNIQUE (booking_reference);
ALTER TABLE payments       ADD CONSTRAINT uk_payment_txn_ref       UNIQUE (transaction_ref);

-- A route operates at most once per day.
ALTER TABLE flights
    ADD COLUMN departure_date DATE GENERATED ALWAYS AS (DATE(departure_time)) VIRTUAL,
    ADD CONSTRAINT uk_flight_route_day UNIQUE (route_id, departure_date);

-- A seat can be held by only one live ticket, and a traveller can hold only
-- one live ticket on a flight. Cancelled tickets get NULL and stop competing.
ALTER TABLE ticket_details
    ADD COLUMN active_seat VARCHAR(4)
        GENERATED ALWAYS AS (IF(ticket_status = 'Cancelled', NULL, seat_number)) VIRTUAL,
    ADD COLUMN active_traveller INT
        GENERATED ALWAYS AS (IF(ticket_status = 'Cancelled', NULL, passenger_id)) VIRTUAL,
    ADD CONSTRAINT uk_ticket_seat      UNIQUE (flight_id, active_seat),
    ADD CONSTRAINT uk_ticket_traveller UNIQUE (flight_id, active_traveller);

-- At most one successful payment per booking (failed attempts are allowed).
ALTER TABLE payments
    ADD COLUMN success_booking INT
        GENERATED ALWAYS AS (IF(payment_status = 'Success', booking_id, NULL)) VIRTUAL,
    ADD CONSTRAINT uk_one_successful_payment UNIQUE (success_booking);

/* ============================ B. CHECK ============================= */
ALTER TABLE airports
    ADD CONSTRAINT ck_airport_code CHECK (airport_code REGEXP '^[A-Z]{3}$');

ALTER TABLE aircraft
    ADD CONSTRAINT ck_aircraft_seats CHECK (economy_seats > 0 AND premium_seats >= 0
                                            AND business_seats >= 0 AND first_seats >= 0),
    ADD CONSTRAINT ck_aircraft_registration CHECK (registration REGEXP '^VT-[A-Z]{3}$');

ALTER TABLE travel_classes
    ADD CONSTRAINT ck_class_multiplier CHECK (fare_multiplier BETWEEN 1.00 AND 10.00),
    ADD CONSTRAINT ck_class_baggage    CHECK (checked_baggage_kg BETWEEN 0 AND 60);

ALTER TABLE routes
    ADD CONSTRAINT ck_route_airports CHECK (origin_code <> destination_code),
    ADD CONSTRAINT ck_route_duration CHECK (duration_min BETWEEN 20 AND 1200),
    ADD CONSTRAINT ck_route_distance CHECK (distance_km > 0),
    ADD CONSTRAINT ck_route_flight_no CHECK (flight_number REGEXP '^[A-Z]{2}[0-9]{2,4}$');

ALTER TABLE flights
    ADD CONSTRAINT ck_flight_times CHECK (arrival_time > departure_time),
    ADD CONSTRAINT ck_flight_price CHECK (base_price > 0);

ALTER TABLE passengers
    ADD CONSTRAINT ck_passenger_email    CHECK (email REGEXP '^[^@ ]+@[^@ ]+\\.[a-z]{2,}$'),
    ADD CONSTRAINT ck_passenger_phone    CHECK (phone REGEXP '^\\+?[0-9]{10,13}$'),
    ADD CONSTRAINT ck_passenger_passport CHECK (passport_number REGEXP '^[A-Z0-9]{6,9}$'),
    ADD CONSTRAINT ck_passenger_dob      CHECK (date_of_birth >= '1900-01-01');

ALTER TABLE bookings
    ADD CONSTRAINT ck_booking_reference CHECK (booking_reference REGEXP '^[A-Z0-9]{6}$');

ALTER TABLE ticket_details
    ADD CONSTRAINT ck_ticket_seat CHECK (seat_number REGEXP '^[0-9]{1,2}[A-K]$'),
    ADD CONSTRAINT ck_ticket_fare CHECK (fare > 0);

ALTER TABLE payments
    ADD CONSTRAINT ck_payment_amount CHECK (amount > 0);

/* ============================ C. DEFAULT ============================ */
ALTER TABLE airports       ALTER country          SET DEFAULT 'India';
ALTER TABLE aircraft       ALTER premium_seats    SET DEFAULT 0;
ALTER TABLE aircraft       ALTER business_seats   SET DEFAULT 0;
ALTER TABLE aircraft       ALTER first_seats      SET DEFAULT 0;
ALTER TABLE aircraft       ALTER status           SET DEFAULT 'Active';
ALTER TABLE flights        ALTER flight_status    SET DEFAULT 'Scheduled';
ALTER TABLE passengers     ALTER nationality      SET DEFAULT 'Indian';
ALTER TABLE bookings       ALTER booking_date     SET DEFAULT (CURRENT_TIMESTAMP);
ALTER TABLE bookings       ALTER status           SET DEFAULT 'Pending';
ALTER TABLE ticket_details ALTER class_code       SET DEFAULT 'EC';
ALTER TABLE ticket_details ALTER ticket_status    SET DEFAULT 'Booked';
ALTER TABLE payments       ALTER payment_status   SET DEFAULT 'Pending';
ALTER TABLE payments       ALTER transaction_date SET DEFAULT (CURRENT_TIMESTAMP);

/* ============================ D. TRIGGERS =========================== */
DELIMITER //

-- Selling a seat: the flight must still be open for sale, the cabin must
-- have a free seat, and the fare defaults to base price x class multiplier.
CREATE TRIGGER trg_ticket_before_insert
BEFORE INSERT ON ticket_details
FOR EACH ROW
BEGIN
    DECLARE v_status     VARCHAR(10);
    DECLARE v_price      DECIMAL(10,2);
    DECLARE v_capacity   SMALLINT;
    DECLARE v_sold       INT;
    DECLARE v_multiplier DECIMAL(4,2);

    SELECT f.flight_status, f.base_price,
           CASE NEW.class_code
               WHEN 'EC' THEN a.economy_seats  WHEN 'PE' THEN a.premium_seats
               WHEN 'BU' THEN a.business_seats WHEN 'FC' THEN a.first_seats END
      INTO v_status, v_price, v_capacity
      FROM flights f JOIN aircraft a ON a.aircraft_id = f.aircraft_id
     WHERE f.flight_id = NEW.flight_id;

    IF v_status NOT IN ('Scheduled', 'Delayed') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket refused: flight is no longer open for booking';
    END IF;

    SELECT COUNT(*) INTO v_sold FROM ticket_details
     WHERE flight_id = NEW.flight_id AND class_code = NEW.class_code
       AND ticket_status <> 'Cancelled';
    IF v_sold >= v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ticket refused: no seats left in this travel class';
    END IF;

    IF NEW.fare IS NULL THEN
        SELECT fare_multiplier INTO v_multiplier
          FROM travel_classes WHERE class_code = NEW.class_code;
        SET NEW.fare = ROUND(v_price * v_multiplier, 2);
    END IF;
END//

-- Cancelling a flight cancels every live ticket on it.
CREATE TRIGGER trg_flight_after_update
AFTER UPDATE ON flights
FOR EACH ROW
BEGIN
    IF NEW.flight_status = 'Cancelled' AND OLD.flight_status <> 'Cancelled' THEN
        UPDATE ticket_details SET ticket_status = 'Cancelled'
         WHERE flight_id = NEW.flight_id AND ticket_status <> 'Cancelled';
    END IF;
END//

-- A cancelled booking cannot receive a new pending or successful payment.
CREATE TRIGGER trg_payment_before_insert
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    IF NEW.payment_status IN ('Pending', 'Success') AND
       (SELECT status FROM bookings WHERE booking_id = NEW.booking_id) = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment refused: booking is cancelled';
    END IF;
END//

DELIMITER ;
