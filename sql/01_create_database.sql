/* =====================================================================
   Airline Reservation & Flight Booking System
   Assignment 5 : database and table creation (MySQL 8.0)

   Finalized design produced by the Assignment 3 analysis of the six
   proposed tables (Passengers, Airports, Flights, Bookings,
   Ticket_Details, Payments):
     - Flights split into routes (the recurring flight number and its
       airports) and flights (one dated departure of a route)
     - total_seats moved to a new aircraft table, per travel class
     - travel class rules (fare multiplier, baggage) in travel_classes
     - Bookings.total_fare removed (derived from ticket fares; view)
     - Ticket_Details gets the travelling passenger and a ticket status
     - Payments gets an amount and a transaction reference, and a
       booking may have several payment attempts (1 : N)
   UNIQUE / CHECK / DEFAULT constraints and triggers: 02_constraints.sql
   ===================================================================== */

DROP DATABASE IF EXISTS airline_reservation;
CREATE DATABASE airline_reservation
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE airline_reservation;

/* ---------- airports : identified by their IATA code ---------- */
CREATE TABLE airports (
    airport_code  CHAR(3)       NOT NULL,
    airport_name  VARCHAR(100)  NOT NULL,
    city          VARCHAR(50)   NOT NULL,
    country       VARCHAR(50)   NOT NULL,
    PRIMARY KEY (airport_code)
) ENGINE = InnoDB;

/* ---------- aircraft : the fleet and its seat layout ---------- */
CREATE TABLE aircraft (
    aircraft_id       SMALLINT     NOT NULL AUTO_INCREMENT,
    registration      VARCHAR(10)  NOT NULL,
    model             VARCHAR(40)  NOT NULL,
    economy_seats     SMALLINT     NOT NULL,
    premium_seats     SMALLINT     NOT NULL,
    business_seats    SMALLINT     NOT NULL,
    first_seats       SMALLINT     NOT NULL,
    in_service_since  DATE         NOT NULL,
    status            ENUM('Active', 'Maintenance', 'Retired') NOT NULL,
    PRIMARY KEY (aircraft_id)
) ENGINE = InnoDB;

/* ---------- travel_classes : rules that belong to a cabin class ---------- */
CREATE TABLE travel_classes (
    class_code          CHAR(2)       NOT NULL,
    class_name          VARCHAR(20)   NOT NULL,
    fare_multiplier     DECIMAL(4,2)  NOT NULL,
    checked_baggage_kg  TINYINT       NOT NULL,
    PRIMARY KEY (class_code)
) ENGINE = InnoDB;

/* ---------- routes : a flight number flown regularly between two airports ---------- */
CREATE TABLE routes (
    route_id             SMALLINT     NOT NULL AUTO_INCREMENT,
    flight_number        VARCHAR(8)   NOT NULL,
    origin_code          CHAR(3)      NOT NULL,
    destination_code     CHAR(3)      NOT NULL,
    scheduled_departure  TIME         NOT NULL,
    duration_min         SMALLINT     NOT NULL,
    distance_km          SMALLINT     NOT NULL,
    PRIMARY KEY (route_id),
    -- IATA codes never change, so plain RESTRICT is used; it also lets
    -- a CHECK constraint compare origin and destination (MySQL rule)
    CONSTRAINT fk_route_origin FOREIGN KEY (origin_code)
        REFERENCES airports (airport_code)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_route_destination FOREIGN KEY (destination_code)
        REFERENCES airports (airport_code)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE = InnoDB;

/* ---------- flights : one dated departure of a route ---------- */
CREATE TABLE flights (
    flight_id       INT            NOT NULL AUTO_INCREMENT,
    route_id        SMALLINT       NOT NULL,
    aircraft_id     SMALLINT       NOT NULL,
    departure_time  DATETIME       NOT NULL,
    arrival_time    DATETIME       NOT NULL,
    base_price      DECIMAL(10,2)  NOT NULL,
    flight_status   ENUM('Scheduled', 'Delayed', 'Departed', 'Arrived', 'Cancelled') NOT NULL,
    PRIMARY KEY (flight_id),
    CONSTRAINT fk_flight_route FOREIGN KEY (route_id)
        REFERENCES routes (route_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_flight_aircraft FOREIGN KEY (aircraft_id)
        REFERENCES aircraft (aircraft_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

/* ---------- passengers ---------- */
CREATE TABLE passengers (
    passenger_id     INT           NOT NULL AUTO_INCREMENT,
    first_name       VARCHAR(50)   NOT NULL,
    last_name        VARCHAR(50)   NOT NULL,
    email            VARCHAR(100)  NOT NULL,
    phone            VARCHAR(15)   NOT NULL,
    passport_number  VARCHAR(20)   NOT NULL,
    nationality      VARCHAR(50)   NOT NULL,
    date_of_birth    DATE          NOT NULL,
    PRIMARY KEY (passenger_id)
) ENGINE = InnoDB;

/* ---------- bookings : one reservation (PNR) made by a passenger ---------- */
CREATE TABLE bookings (
    booking_id         INT          NOT NULL AUTO_INCREMENT,
    passenger_id       INT          NOT NULL,          -- who made the booking
    booking_reference  CHAR(6)      NOT NULL,          -- the PNR
    booking_date       DATETIME     NOT NULL,
    status             ENUM('Pending', 'Confirmed', 'Cancelled') NOT NULL,
    PRIMARY KEY (booking_id),
    CONSTRAINT fk_booking_passenger FOREIGN KEY (passenger_id)
        REFERENCES passengers (passenger_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

/* ---------- ticket_details : one seat on one flight for one traveller ---------- */
CREATE TABLE ticket_details (
    ticket_id      INT            NOT NULL AUTO_INCREMENT,
    booking_id     INT            NOT NULL,
    flight_id      INT            NOT NULL,
    passenger_id   INT            NOT NULL,            -- who is flying
    class_code     CHAR(2)        NOT NULL,
    seat_number    VARCHAR(4)     NOT NULL,
    fare           DECIMAL(10,2)  NOT NULL,            -- price charged (snapshot)
    ticket_status  ENUM('Booked', 'Checked-in', 'Boarded', 'No-show', 'Cancelled') NOT NULL,
    PRIMARY KEY (ticket_id),
    CONSTRAINT fk_ticket_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (booking_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ticket_flight FOREIGN KEY (flight_id)
        REFERENCES flights (flight_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ticket_passenger FOREIGN KEY (passenger_id)
        REFERENCES passengers (passenger_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ticket_class FOREIGN KEY (class_code)
        REFERENCES travel_classes (class_code)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

/* ---------- payments : every payment attempt for a booking ---------- */
CREATE TABLE payments (
    payment_id        INT            NOT NULL AUTO_INCREMENT,
    booking_id        INT            NOT NULL,
    amount            DECIMAL(10,2)  NOT NULL,
    payment_method    ENUM('Credit Card', 'Debit Card', 'Net Banking', 'UPI') NOT NULL,
    payment_status    ENUM('Pending', 'Success', 'Failed', 'Refunded') NOT NULL,
    transaction_ref   VARCHAR(20)    NOT NULL,
    transaction_date  DATETIME       NOT NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (booking_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

/* ---------- derived information as views (no stored redundancy) ---------- */
CREATE VIEW v_booking_totals AS
SELECT b.booking_id, b.booking_reference, b.status,
       COUNT(t.ticket_id)                                         AS active_tickets,
       COALESCE(SUM(t.fare), 0)                                   AS total_fare,
       COALESCE((SELECT SUM(p.amount) FROM payments p
                 WHERE p.booking_id = b.booking_id
                   AND p.payment_status = 'Success'), 0)          AS amount_paid
FROM bookings b
LEFT JOIN ticket_details t
       ON t.booking_id = b.booking_id AND t.ticket_status <> 'Cancelled'
GROUP BY b.booking_id, b.booking_reference, b.status;

CREATE VIEW v_flight_occupancy AS
SELECT f.flight_id, r.flight_number, r.origin_code, r.destination_code,
       f.departure_time, f.flight_status,
       a.economy_seats + a.premium_seats + a.business_seats + a.first_seats AS capacity,
       COUNT(t.ticket_id)                                                    AS seats_sold,
       ROUND(100 * COUNT(t.ticket_id)
             / (a.economy_seats + a.premium_seats + a.business_seats + a.first_seats), 1)
                                                                             AS load_factor_pct
FROM flights f
JOIN routes r   ON r.route_id    = f.route_id
JOIN aircraft a ON a.aircraft_id = f.aircraft_id
LEFT JOIN ticket_details t
       ON t.flight_id = f.flight_id AND t.ticket_status <> 'Cancelled'
GROUP BY f.flight_id, r.flight_number, r.origin_code, r.destination_code,
         f.departure_time, f.flight_status,
         a.economy_seats, a.premium_seats, a.business_seats, a.first_seats;
