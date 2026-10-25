/* Airline Reservation - Assignment 9 : joins and subqueries (run after 05_basic_queries.sql) */
USE airline_reservation;

-- 9.1 Passenger manifest for SW301 on 29 October (6 tables)
SELECT t.seat_number, c.class_name AS cabin,
       CONCAT(p.first_name, ' ', p.last_name) AS traveller,
       p.nationality, p.passport_number, b.booking_reference AS pnr, t.ticket_status
FROM ticket_details t
JOIN passengers     p ON p.passenger_id = t.passenger_id
JOIN bookings       b ON b.booking_id   = t.booking_id
JOIN travel_classes c ON c.class_code   = t.class_code
JOIN flights        f ON f.flight_id    = t.flight_id
JOIN routes         r ON r.route_id     = f.route_id
WHERE r.flight_number = 'SW301'
  AND DATE(f.departure_time) = '2026-10-29'
  AND t.ticket_status <> 'Cancelled'
ORDER BY t.class_code DESC, t.seat_number;

-- 9.2 Itinerary for PNR R7D5DD: a family round trip
SELECT b.booking_reference, CONCAT(bk.first_name, ' ', bk.last_name) AS booked_by,
       b.booking_date, b.status, v.active_tickets, v.total_fare, v.amount_paid
FROM bookings b
JOIN passengers bk       ON bk.passenger_id = b.passenger_id
JOIN v_booking_totals v  ON v.booking_id    = b.booking_id
WHERE b.booking_reference = 'R7D5DD';

SELECT r.flight_number, r.origin_code AS from_, r.destination_code AS to_,
       f.departure_time, CONCAT(p.first_name, ' ', p.last_name) AS traveller,
       t.seat_number, t.fare
FROM ticket_details t
JOIN bookings   b ON b.booking_id   = t.booking_id
JOIN flights    f ON f.flight_id    = t.flight_id
JOIN routes     r ON r.route_id     = f.route_id
JOIN passengers p ON p.passenger_id = t.passenger_id
WHERE b.booking_reference = 'R7D5DD'
ORDER BY f.departure_time, t.seat_number;

-- 9.3 Load factor of the ten busiest completed flights (join with a view)
SELECT o.flight_number, o.origin_code, o.destination_code, DATE(o.departure_time) AS flown_on,
       a.model, o.capacity, o.seats_sold, o.load_factor_pct
FROM v_flight_occupancy o
JOIN flights  f ON f.flight_id   = o.flight_id
JOIN aircraft a ON a.aircraft_id = f.aircraft_id
WHERE o.flight_status = 'Arrived'
ORDER BY o.seats_sold DESC, o.departure_time
LIMIT 10;

-- 9.4 Flights without a single live ticket (LEFT JOIN)
SELECT f.flight_id, r.flight_number, f.departure_time, f.flight_status
FROM flights f
JOIN routes r ON r.route_id = f.route_id
LEFT JOIN ticket_details t
       ON t.flight_id = f.flight_id AND t.ticket_status <> 'Cancelled'
WHERE t.ticket_id IS NULL
ORDER BY f.departure_time;

-- 9.5 Registered passengers who have never booked or travelled (anti-join)
SELECT p.passenger_id, p.first_name, p.last_name, p.email
FROM passengers p
LEFT JOIN bookings b       ON b.passenger_id = p.passenger_id
LEFT JOIN ticket_details t ON t.passenger_id = p.passenger_id
WHERE b.booking_id IS NULL AND t.ticket_id IS NULL;

-- 9.6 Routes and their return route (self join)
SELECT o.flight_number AS outbound, o.origin_code, o.destination_code,
       i.flight_number AS inbound, o.scheduled_departure AS out_time, i.scheduled_departure AS back_time
FROM routes o
JOIN routes i ON i.origin_code = o.destination_code
             AND i.destination_code = o.origin_code
WHERE o.origin_code = 'HYD'
ORDER BY o.flight_number;

-- 9.7 Revenue and traffic per route
SELECT r.flight_number, CONCAT(r.origin_code, '-', r.destination_code) AS sector,
       COUNT(DISTINCT f.flight_id)                 AS flights_with_pax,
       SUM(t.ticket_status = 'Boarded')            AS boarded,
       SUM(t.fare)                                 AS revenue,
       ROUND(AVG(t.fare))                          AS avg_fare
FROM routes r
JOIN flights f        ON f.route_id  = r.route_id
JOIN ticket_details t ON t.flight_id = f.flight_id AND t.ticket_status <> 'Cancelled'
GROUP BY r.route_id, r.flight_number, r.origin_code, r.destination_code
ORDER BY revenue DESC;

-- 9.8 Revenue by cabin on each sector (cross-tab)
SELECT CONCAT(r.origin_code, '-', r.destination_code) AS sector,
       SUM(IF(t.class_code = 'EC', t.fare, 0)) AS economy,
       SUM(IF(t.class_code = 'PE', t.fare, 0)) AS premium,
       SUM(IF(t.class_code = 'BU', t.fare, 0)) AS business,
       SUM(IF(t.class_code = 'FC', t.fare, 0)) AS first_class,
       SUM(t.fare)                             AS total
FROM ticket_details t
JOIN flights f ON f.flight_id = t.flight_id
JOIN routes  r ON r.route_id  = f.route_id
WHERE t.ticket_status <> 'Cancelled'
GROUP BY r.origin_code, r.destination_code
ORDER BY total DESC
LIMIT 10;

-- 9.9 Revenue by destination country and city with subtotals (WITH ROLLUP)
SELECT IF(GROUPING(country), 'ALL COUNTRIES', country) AS country,
       IF(GROUPING(city), IF(GROUPING(country), '', '(subtotal)'), city) AS city,
       COUNT(*) AS tickets, SUM(fare) AS revenue
FROM (SELECT a.country, a.city, t.fare
      FROM ticket_details t
      JOIN flights  f ON f.flight_id      = t.flight_id
      JOIN routes   r ON r.route_id       = f.route_id
      JOIN airports a ON a.airport_code   = r.destination_code
      WHERE t.ticket_status <> 'Cancelled') AS x
GROUP BY country, city WITH ROLLUP;

-- 9.10 Ranking routes by revenue within domestic and international (window function)
SELECT IF(orig.country = 'India' AND dest.country = 'India', 'Domestic', 'International') AS market,
       r.flight_number, SUM(t.fare) AS revenue,
       RANK() OVER (PARTITION BY IF(orig.country = 'India' AND dest.country = 'India', 'Domestic', 'International')
                    ORDER BY SUM(t.fare) DESC) AS rank_in_market
FROM ticket_details t
JOIN flights  f    ON f.flight_id      = t.flight_id
JOIN routes   r    ON r.route_id       = f.route_id
JOIN airports orig ON orig.airport_code = r.origin_code
JOIN airports dest ON dest.airport_code = r.destination_code
WHERE t.ticket_status <> 'Cancelled'
GROUP BY market, r.flight_number, dest.country, orig.country
ORDER BY market, rank_in_market;

-- 9.11 Bookings worth more than the average booking (scalar subquery)
SELECT booking_id, booking_reference, active_tickets, total_fare
FROM v_booking_totals
WHERE status = 'Confirmed'
  AND total_fare > (SELECT AVG(total_fare) FROM v_booking_totals WHERE status = 'Confirmed')
ORDER BY total_fare DESC
LIMIT 10;

-- 9.12 Passengers who have flown internationally (nested IN)
SELECT passenger_id, first_name, last_name, nationality
FROM passengers
WHERE passenger_id IN (
    SELECT t.passenger_id FROM ticket_details t
    WHERE t.ticket_status = 'Boarded'
      AND t.flight_id IN (
          SELECT f.flight_id FROM flights f
          WHERE f.route_id IN (
              SELECT r.route_id FROM routes r
              JOIN airports a ON a.airport_code = r.destination_code
                              OR a.airport_code = r.origin_code
              WHERE a.country <> 'India')))
ORDER BY last_name, first_name;

-- 9.13 Each traveller's most recent completed flight (correlated subquery)
SELECT CONCAT(p.first_name, ' ', p.last_name) AS traveller, r.flight_number,
       r.origin_code, r.destination_code, f.departure_time
FROM ticket_details t
JOIN passengers p ON p.passenger_id = t.passenger_id
JOIN flights    f ON f.flight_id    = t.flight_id
JOIN routes     r ON r.route_id     = f.route_id
WHERE t.ticket_status = 'Boarded'
  AND f.departure_time = (SELECT MAX(f2.departure_time)
                          FROM ticket_details t2
                          JOIN flights f2 ON f2.flight_id = t2.flight_id
                          WHERE t2.passenger_id = t.passenger_id
                            AND t2.ticket_status = 'Boarded')
ORDER BY f.departure_time DESC
LIMIT 15;

-- 9.14 Customers who booked but have never actually flown (NOT EXISTS)
SELECT p.passenger_id, p.first_name, p.last_name,
       (SELECT COUNT(*) FROM bookings b WHERE b.passenger_id = p.passenger_id) AS bookings_made
FROM passengers p
WHERE EXISTS (SELECT 1 FROM bookings b WHERE b.passenger_id = p.passenger_id)
  AND NOT EXISTS (SELECT 1 FROM ticket_details t
                  WHERE t.passenger_id = p.passenger_id AND t.ticket_status = 'Boarded');

-- 9.15 Bookings that needed a retry: a failed attempt followed by a success (EXISTS)
SELECT b.booking_reference,
       (SELECT GROUP_CONCAT(p.payment_method, ':', p.payment_status ORDER BY p.transaction_date SEPARATOR ' -> ')
        FROM payments p WHERE p.booking_id = b.booking_id) AS attempts,
       (SELECT amount FROM payments p WHERE p.booking_id = b.booking_id
                                        AND p.payment_status = 'Success') AS paid
FROM bookings b
WHERE EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = b.booking_id AND p.payment_status = 'Failed')
  AND EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = b.booking_id AND p.payment_status = 'Success')
ORDER BY b.booking_id
LIMIT 12;

-- 9.16 Customer value segments by total spend (derived table + CASE)
SELECT segment, COUNT(*) AS customers, ROUND(AVG(spend)) AS avg_spend, SUM(spend) AS total_spend
FROM (SELECT b.passenger_id, SUM(p.amount) AS spend,
             CASE WHEN SUM(p.amount) >= 60000 THEN 'Platinum'
                  WHEN SUM(p.amount) >= 25000 THEN 'Gold'
                  ELSE 'Silver' END AS segment
      FROM bookings b
      JOIN payments p ON p.booking_id = b.booking_id AND p.payment_status = 'Success'
      GROUP BY b.passenger_id) AS spend_per_customer
GROUP BY segment
ORDER BY total_spend DESC;

-- 9.17 Daily ticket revenue in October with a running total (CTE + SUM OVER)
WITH daily AS (
    SELECT DATE(f.departure_time) AS flight_day, SUM(t.fare) AS revenue
    FROM ticket_details t
    JOIN flights f ON f.flight_id = t.flight_id
    WHERE t.ticket_status IN ('Boarded', 'No-show')
      AND f.departure_time >= '2026-10-01'
    GROUP BY DATE(f.departure_time)
)
SELECT flight_day, revenue,
       SUM(revenue) OVER (ORDER BY flight_day) AS running_total
FROM daily
ORDER BY flight_day;

-- 9.18 Fleet utilization: flights and block hours per aircraft (LEFT JOIN + derived values)
SELECT a.registration, a.model, a.status,
       COUNT(f.flight_id)                                                  AS flights_flown,
       ROUND(COALESCE(SUM(TIMESTAMPDIFF(MINUTE, f.departure_time, f.arrival_time)), 0) / 60, 1)
                                                                           AS block_hours
FROM aircraft a
LEFT JOIN flights f ON f.aircraft_id = a.aircraft_id AND f.flight_status = 'Arrived'
GROUP BY a.aircraft_id, a.registration, a.model, a.status
ORDER BY block_hours DESC;

-- 9.19 Refund report: why each cancelled booking was refunded
SELECT b.booking_reference, b.status, p.amount AS refunded,
       CASE WHEN EXISTS (SELECT 1 FROM ticket_details t
                         JOIN flights f ON f.flight_id = t.flight_id
                         WHERE t.booking_id = b.booking_id AND f.flight_status = 'Cancelled')
            THEN 'Flight cancelled by airline'
            ELSE 'Cancelled by passenger' END AS reason
FROM bookings b
JOIN payments p ON p.booking_id = b.booking_id AND p.payment_status = 'Refunded'
ORDER BY reason, refunded DESC;
