/* Airline Reservation - Assignment 8 : basic SQL queries and aggregate functions
   Run after 04_sample_data.sql. Part F changes data. */
USE airline_reservation;

-- 8.1 International airports in the network
SELECT airport_code, airport_name, city, country
FROM airports
WHERE country <> 'India';

-- 8.2 Long routes (over 1,000 km) that take more than two hours
SELECT flight_number, origin_code, destination_code, distance_km, duration_min
FROM routes
WHERE distance_km > 1000
  AND duration_min > 120;

-- 8.3 Flights departing in the week of 20–26 October (BETWEEN)
SELECT flight_id, route_id, departure_time, flight_status
FROM flights
WHERE departure_time BETWEEN '2026-10-20 00:00:00' AND '2026-10-26 23:59:59';

-- 8.4 Passengers whose last name is Reddy or Rao, or who are not Indian (LIKE, IN)
SELECT passenger_id, first_name, last_name, nationality
FROM passengers
WHERE last_name IN ('Reddy', 'Rao')
   OR nationality NOT IN ('Indian');

-- 8.5 Seats by the window: tickets in seat A or F (LIKE patterns)
SELECT ticket_id, flight_id, passenger_id, seat_number, class_code
FROM ticket_details
WHERE (seat_number LIKE '%A' OR seat_number LIKE '%F')
  AND class_code = 'BU';

-- 8.6 Bookings that are not yet paid
SELECT booking_id, booking_reference, passenger_id, booking_date
FROM bookings
WHERE status = 'Pending';

-- 8.7 Failed payment attempts above ₹10,000
SELECT payment_id, booking_id, amount, payment_method, transaction_date
FROM payments
WHERE payment_status = 'Failed'
  AND amount > 10000;

-- 8.8 The ten most expensive tickets sold
SELECT ticket_id, flight_id, class_code, fare
FROM ticket_details
ORDER BY fare DESC
LIMIT 10;

-- 8.9 Routes ordered by distance, then by flight number
SELECT flight_number, origin_code, destination_code, distance_km
FROM routes
ORDER BY distance_km DESC, flight_number ASC;

-- 8.10 Upcoming departures, earliest first
SELECT flight_id, route_id, departure_time, flight_status
FROM flights
WHERE departure_time > '2026-10-25 14:00:00'
ORDER BY departure_time
LIMIT 8;

-- 8.11 COUNT – size of the operation
SELECT COUNT(*)                     AS tickets_issued,
       COUNT(DISTINCT passenger_id)  AS different_travellers,
       COUNT(DISTINCT flight_id)     AS flights_with_passengers,
       COUNT(DISTINCT booking_id)    AS bookings
FROM ticket_details;

-- 8.12 SUM – money collected, refunded and still pending
SELECT SUM(CASE WHEN payment_status = 'Success'  THEN amount ELSE 0 END) AS collected,
       SUM(CASE WHEN payment_status = 'Refunded' THEN amount ELSE 0 END) AS refunded,
       SUM(CASE WHEN payment_status = 'Pending'  THEN amount ELSE 0 END) AS awaiting
FROM payments;

-- 8.13 AVG – average fare and average flight length
SELECT ROUND(AVG(fare), 2) AS avg_fare_all_tickets
FROM ticket_details
WHERE ticket_status <> 'Cancelled';

SELECT ROUND(AVG(duration_min)) AS avg_duration_min, ROUND(AVG(distance_km)) AS avg_distance_km
FROM routes;

-- 8.14 MIN and MAX – cheapest and dearest base price, first and last departure
SELECT MIN(base_price) AS lowest_base, MAX(base_price) AS highest_base,
       MIN(departure_time) AS first_departure, MAX(departure_time) AS last_departure
FROM flights;

-- 8.15 All five aggregates on successful payments
SELECT COUNT(*)              AS payments,
       SUM(amount)           AS revenue,
       ROUND(AVG(amount), 2) AS avg_booking_value,
       MIN(amount)           AS smallest,
       MAX(amount)           AS largest
FROM payments
WHERE payment_status = 'Success';

-- 8.16 Tickets and revenue by travel class
SELECT class_code, COUNT(*) AS tickets, SUM(fare) AS revenue, ROUND(AVG(fare), 2) AS avg_fare
FROM ticket_details
WHERE ticket_status <> 'Cancelled'
GROUP BY class_code
ORDER BY revenue DESC;

-- 8.17 Flights per operational status
SELECT flight_status, COUNT(*) AS flights
FROM flights
GROUP BY flight_status;

-- 8.18 Bookings made per month
SELECT DATE_FORMAT(booking_date, '%Y-%m') AS month,
       COUNT(*)                          AS bookings,
       SUM(status = 'Cancelled')         AS cancelled
FROM bookings
GROUP BY DATE_FORMAT(booking_date, '%Y-%m')
ORDER BY month;

-- 8.19 Payment attempts by method and outcome
SELECT payment_method, payment_status, COUNT(*) AS attempts
FROM payments
GROUP BY payment_method, payment_status
ORDER BY payment_method, attempts DESC;

-- 8.20 Ticket status breakdown
SELECT ticket_status, COUNT(*) AS tickets
FROM ticket_details
GROUP BY ticket_status
ORDER BY tickets DESC;

-- 8.21 Frequent flyers: travellers with more than six tickets
SELECT passenger_id, COUNT(*) AS tickets
FROM ticket_details
WHERE ticket_status <> 'Cancelled'
GROUP BY passenger_id
HAVING COUNT(*) > 6
ORDER BY tickets DESC;

-- 8.22 Busy flights: more than six live tickets
SELECT flight_id, COUNT(*) AS seats_sold
FROM ticket_details
WHERE ticket_status <> 'Cancelled'
GROUP BY flight_id
HAVING seats_sold > 6
ORDER BY seats_sold DESC;

-- 8.23 Payment methods with a failure rate above 10 %
SELECT payment_method,
       COUNT(*)                                          AS attempts,
       SUM(payment_status = 'Failed')                    AS failed,
       ROUND(100 * SUM(payment_status = 'Failed') / COUNT(*), 1) AS failure_pct
FROM payments
GROUP BY payment_method
HAVING failure_pct > 10;

-- 8.24 Bookings worth more than ₹20,000
SELECT booking_id, COUNT(*) AS tickets, SUM(fare) AS booking_value
FROM ticket_details
WHERE ticket_status <> 'Cancelled'
GROUP BY booking_id
HAVING SUM(fare) > 20000
ORDER BY booking_value DESC;

-- 8.25 UPDATE – a larger aircraft is assigned to a flight
SELECT flight_id, flight_number, capacity, seats_sold, load_factor_pct
FROM v_flight_occupancy WHERE flight_id = 17;

UPDATE flights SET aircraft_id = 3 WHERE flight_id = 17;

SELECT flight_id, flight_number, capacity, seats_sold, load_factor_pct
FROM v_flight_occupancy WHERE flight_id = 17;

-- 8.26 UPDATE – a pending payment succeeds and the booking is confirmed
UPDATE payments SET payment_status = 'Success' WHERE payment_id = 57;
UPDATE bookings SET status = 'Confirmed' WHERE booking_id = 51;

SELECT booking_id, booking_reference, status, total_fare, amount_paid
FROM v_booking_totals WHERE booking_id = 51;

-- 8.27 DELETE – housekeeping of old failed payment attempts
SELECT COUNT(*) AS old_failed FROM payments
WHERE payment_status = 'Failed' AND transaction_date < '2026-09-01';

DELETE FROM payments
WHERE payment_status = 'Failed'
  AND transaction_date < '2026-09-01';

SELECT payment_status, COUNT(*) AS attempts FROM payments GROUP BY payment_status;
