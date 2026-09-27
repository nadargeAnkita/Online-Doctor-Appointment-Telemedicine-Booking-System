/*==============================================================================
  ONLINE DOCTOR APPOINTMENT & TELEMEDICINE BOOKING SYSTEM
  Platform : Oracle SQL / SQL*Plus
  Author   : Ankita
  Purpose  : Portfolio project - relational schema, sample data, views,
             PL/SQL procedures, functions, and triggers for a doctor
             appointment booking + telemedicine consultation platform.

  HOW TO RUN (SQL*Plus):
      sqlplus username/password@db
      SQL> @doctor_appointment_telemedicine_system.sql
      SQL> SPOOL doctor_appointment_output.txt
      SQL> @doctor_appointment_telemedicine_system.sql
      SQL> SPOOL OFF
==============================================================================*/

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 150;
SET PAGESIZE 100;
SET FEEDBACK ON;
WHENEVER SQLERROR CONTINUE;

/*==============================================================================
  0. CLEAN SLATE - Drop existing objects if re-running the script
==============================================================================*/
BEGIN
   FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN
     ('REVIEWS','PAYMENTS','VIDEO_CONSULTATIONS','PRESCRIPTIONS',
      'APPOINTMENTS','DOCTOR_AVAILABILITY','DOCTORS','PATIENTS','SPECIALIZATIONS'))
   LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
   END LOOP;
   FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name LIKE 'SEQ_%')
   LOOP
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
   END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

/*==============================================================================
  1. SEQUENCES
==============================================================================*/
CREATE SEQUENCE seq_patient_id   START WITH 1001 INCREMENT BY 1;
CREATE SEQUENCE seq_doctor_id    START WITH 2001 INCREMENT BY 1;
CREATE SEQUENCE seq_spec_id      START WITH 1    INCREMENT BY 1;
CREATE SEQUENCE seq_slot_id      START WITH 5001 INCREMENT BY 1;
CREATE SEQUENCE seq_appt_id      START WITH 9001 INCREMENT BY 1;
CREATE SEQUENCE seq_presc_id     START WITH 7001 INCREMENT BY 1;
CREATE SEQUENCE seq_payment_id   START WITH 6001 INCREMENT BY 1;
CREATE SEQUENCE seq_video_id     START WITH 8001 INCREMENT BY 1;
CREATE SEQUENCE seq_review_id    START WITH 4001 INCREMENT BY 1;

/*==============================================================================
  2. TABLES
==============================================================================*/

-- Specializations (Cardiology, Dermatology, etc.)
CREATE TABLE specializations (
    spec_id         NUMBER(5)       PRIMARY KEY,
    spec_name       VARCHAR2(60)    NOT NULL UNIQUE,
    consult_fee_avg NUMBER(8,2)     CHECK (consult_fee_avg >= 0)
);

-- Patients
CREATE TABLE patients (
    patient_id      NUMBER(6)       PRIMARY KEY,
    full_name       VARCHAR2(80)    NOT NULL,
    gender          CHAR(1)         CHECK (gender IN ('M','F','O')),
    dob             DATE            CHECK (dob < SYSDATE),
    phone           VARCHAR2(15)    NOT NULL UNIQUE,
    email           VARCHAR2(100)   UNIQUE,
    city            VARCHAR2(50),
    registered_on   DATE            DEFAULT SYSDATE NOT NULL
);

-- Doctors
CREATE TABLE doctors (
    doctor_id       NUMBER(6)       PRIMARY KEY,
    full_name       VARCHAR2(80)    NOT NULL,
    spec_id         NUMBER(5)       NOT NULL,
    qualification   VARCHAR2(100),
    experience_yrs  NUMBER(3)       CHECK (experience_yrs >= 0),
    consult_fee     NUMBER(8,2)     CHECK (consult_fee >= 0),
    phone           VARCHAR2(15)    UNIQUE,
    email           VARCHAR2(100)   UNIQUE,
    is_active       CHAR(1)         DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    CONSTRAINT fk_doc_spec FOREIGN KEY (spec_id) REFERENCES specializations(spec_id)
);

-- Doctor availability slots (per doctor, per date/time)
CREATE TABLE doctor_availability (
    slot_id         NUMBER(8)       PRIMARY KEY,
    doctor_id       NUMBER(6)       NOT NULL,
    slot_date       DATE            NOT NULL,
    start_time      VARCHAR2(5)     NOT NULL,   -- 'HH24:MI' e.g. '10:30'
    end_time        VARCHAR2(5)     NOT NULL,
    mode            VARCHAR2(12)    DEFAULT 'ONLINE' CHECK (mode IN ('ONLINE','IN-PERSON')),
    slot_status     VARCHAR2(10)    DEFAULT 'FREE' CHECK (slot_status IN ('FREE','BOOKED','CLOSED')),
    CONSTRAINT fk_slot_doc FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
    CONSTRAINT uq_doc_slot UNIQUE (doctor_id, slot_date, start_time)
);

-- Appointments (booking header)
CREATE TABLE appointments (
    appt_id         NUMBER(8)       PRIMARY KEY,
    patient_id      NUMBER(6)       NOT NULL,
    doctor_id       NUMBER(6)       NOT NULL,
    slot_id         NUMBER(8)       NOT NULL UNIQUE,
    booked_on       DATE            DEFAULT SYSDATE NOT NULL,
    appt_status     VARCHAR2(12)    DEFAULT 'CONFIRMED'
                        CHECK (appt_status IN ('CONFIRMED','CANCELLED','COMPLETED','NO-SHOW')),
    symptoms        VARCHAR2(300),
    CONSTRAINT fk_appt_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
    CONSTRAINT fk_appt_doctor  FOREIGN KEY (doctor_id)  REFERENCES doctors(doctor_id),
    CONSTRAINT fk_appt_slot    FOREIGN KEY (slot_id)    REFERENCES doctor_availability(slot_id)
);

-- Video consultation sessions (telemedicine link, linked 1:1 to an appointment)
CREATE TABLE video_consultations (
    video_id        NUMBER(8)       PRIMARY KEY,
    appt_id         NUMBER(8)       NOT NULL UNIQUE,
    meeting_link    VARCHAR2(200)   NOT NULL,
    started_at      TIMESTAMP,
    ended_at        TIMESTAMP,
    call_status     VARCHAR2(12)    DEFAULT 'SCHEDULED'
                        CHECK (call_status IN ('SCHEDULED','ONGOING','ENDED','MISSED')),
    CONSTRAINT fk_video_appt FOREIGN KEY (appt_id) REFERENCES appointments(appt_id)
);

-- Prescriptions issued after consultation
CREATE TABLE prescriptions (
    presc_id        NUMBER(8)       PRIMARY KEY,
    appt_id         NUMBER(8)       NOT NULL UNIQUE,
    diagnosis       VARCHAR2(300),
    medicines       VARCHAR2(500),
    advice          VARCHAR2(300),
    issued_on       DATE            DEFAULT SYSDATE,
    CONSTRAINT fk_presc_appt FOREIGN KEY (appt_id) REFERENCES appointments(appt_id)
);

-- Payments
CREATE TABLE payments (
    payment_id      NUMBER(8)       PRIMARY KEY,
    appt_id         NUMBER(8)       NOT NULL UNIQUE,
    amount          NUMBER(8,2)     NOT NULL CHECK (amount >= 0),
    payment_mode    VARCHAR2(12)    CHECK (payment_mode IN ('UPI','CARD','NETBANKING','WALLET','CASH')),
    payment_status  VARCHAR2(10)    DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING','PAID','REFUNDED','FAILED')),
    paid_on         DATE,
    CONSTRAINT fk_pay_appt FOREIGN KEY (appt_id) REFERENCES appointments(appt_id)
);

-- Patient reviews & ratings for doctors
CREATE TABLE reviews (
    review_id       NUMBER(8)       PRIMARY KEY,
    appt_id         NUMBER(8)       NOT NULL UNIQUE,
    rating          NUMBER(1)       CHECK (rating BETWEEN 1 AND 5),
    review_text     VARCHAR2(400),
    reviewed_on     DATE            DEFAULT SYSDATE,
    CONSTRAINT fk_review_appt FOREIGN KEY (appt_id) REFERENCES appointments(appt_id)
);

/*==============================================================================
  3. SAMPLE DATA
==============================================================================*/

-- Specializations
INSERT INTO specializations VALUES (seq_spec_id.NEXTVAL, 'General Physician', 400);
INSERT INTO specializations VALUES (seq_spec_id.NEXTVAL, 'Cardiology', 900);
INSERT INTO specializations VALUES (seq_spec_id.NEXTVAL, 'Dermatology', 700);
INSERT INTO specializations VALUES (seq_spec_id.NEXTVAL, 'Pediatrics', 500);
INSERT INTO specializations VALUES (seq_spec_id.NEXTVAL, 'Psychiatry', 800);

-- Doctors
INSERT INTO doctors VALUES (seq_doctor_id.NEXTVAL, 'Dr. Rohan Mehta', 1, 'MBBS', 8, 400, '9811100001','rohan.mehta@teledoc.com','Y');
INSERT INTO doctors VALUES (seq_doctor_id.NEXTVAL, 'Dr. Anjali Kulkarni', 2, 'MBBS, MD Cardiology', 12, 950, '9811100002','anjali.kulkarni@teledoc.com','Y');
INSERT INTO doctors VALUES (seq_doctor_id.NEXTVAL, 'Dr. Sameer Iyer', 3, 'MBBS, MD Dermatology', 6, 650, '9811100003','sameer.iyer@teledoc.com','Y');
INSERT INTO doctors VALUES (seq_doctor_id.NEXTVAL, 'Dr. Priya Nair', 4, 'MBBS, DCH', 10, 500, '9811100004','priya.nair@teledoc.com','Y');
INSERT INTO doctors VALUES (seq_doctor_id.NEXTVAL, 'Dr. Karan Shah', 5, 'MBBS, MD Psychiatry', 9, 850, '9811100005','karan.shah@teledoc.com','Y');

-- Patients
INSERT INTO patients VALUES (seq_patient_id.NEXTVAL, 'Ankita Deshmukh', 'F', DATE '2001-04-12', '9922200001','ankita.d@mail.com','Pune',SYSDATE-40);
INSERT INTO patients VALUES (seq_patient_id.NEXTVAL, 'Rahul Verma', 'M', DATE '1995-11-02', '9922200002','rahul.v@mail.com','Mumbai',SYSDATE-30);
INSERT INTO patients VALUES (seq_patient_id.NEXTVAL, 'Sneha Joshi', 'F', DATE '1998-06-25', '9922200003','sneha.j@mail.com','Nagpur',SYSDATE-20);
INSERT INTO patients VALUES (seq_patient_id.NEXTVAL, 'Amit Kadam', 'M', DATE '1990-01-15', '9922200004','amit.k@mail.com','Pune',SYSDATE-15);

-- Doctor availability slots
INSERT INTO doctor_availability VALUES (seq_slot_id.NEXTVAL, 2001, TRUNC(SYSDATE)+1, '10:00','10:20','ONLINE','FREE');
INSERT INTO doctor_availability VALUES (seq_slot_id.NEXTVAL, 2001, TRUNC(SYSDATE)+1, '10:20','10:40','ONLINE','FREE');
INSERT INTO doctor_availability VALUES (seq_slot_id.NEXTVAL, 2002, TRUNC(SYSDATE)+1, '11:00','11:30','ONLINE','FREE');
INSERT INTO doctor_availability VALUES (seq_slot_id.NEXTVAL, 2003, TRUNC(SYSDATE)+2, '15:00','15:20','ONLINE','FREE');
INSERT INTO doctor_availability VALUES (seq_slot_id.NEXTVAL, 2004, TRUNC(SYSDATE)+2, '09:00','09:20','IN-PERSON','FREE');
INSERT INTO doctor_availability VALUES (seq_slot_id.NEXTVAL, 2005, TRUNC(SYSDATE)+3, '17:00','17:30','ONLINE','FREE');

COMMIT;

/*==============================================================================
  4. VIEWS
==============================================================================*/

-- Upcoming confirmed appointments with patient, doctor and slot details
CREATE OR REPLACE VIEW vw_upcoming_appointments AS
SELECT a.appt_id, p.full_name AS patient_name, d.full_name AS doctor_name,
       s.spec_name, da.slot_date, da.start_time, da.mode, a.appt_status
FROM   appointments a
JOIN   patients p            ON a.patient_id = p.patient_id
JOIN   doctors d              ON a.doctor_id  = d.doctor_id
JOIN   specializations s      ON d.spec_id    = s.spec_id
JOIN   doctor_availability da ON a.slot_id    = da.slot_id
WHERE  a.appt_status = 'CONFIRMED' AND da.slot_date >= TRUNC(SYSDATE);

-- Doctor rating summary
CREATE OR REPLACE VIEW vw_doctor_ratings AS
SELECT d.doctor_id, d.full_name, ROUND(AVG(r.rating),2) AS avg_rating,
       COUNT(r.review_id) AS total_reviews
FROM   doctors d
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN reviews r      ON a.appt_id   = r.appt_id
GROUP BY d.doctor_id, d.full_name;

-- Revenue collected per doctor
CREATE OR REPLACE VIEW vw_doctor_revenue AS
SELECT d.doctor_id, d.full_name, NVL(SUM(pay.amount),0) AS total_revenue
FROM   doctors d
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN payments pay   ON a.appt_id   = pay.appt_id AND pay.payment_status = 'PAID'
GROUP BY d.doctor_id, d.full_name;

/*==============================================================================
  5. TRIGGERS
==============================================================================*/

-- Mark the slot BOOKED the moment an appointment is created;
-- free the slot again if the appointment is cancelled.
CREATE OR REPLACE TRIGGER trg_slot_on_booking
AFTER INSERT ON appointments
FOR EACH ROW
BEGIN
    UPDATE doctor_availability
    SET    slot_status = 'BOOKED'
    WHERE  slot_id = :NEW.slot_id;
END;
/

CREATE OR REPLACE TRIGGER trg_slot_on_cancel
AFTER UPDATE OF appt_status ON appointments
FOR EACH ROW
WHEN (NEW.appt_status = 'CANCELLED' AND OLD.appt_status <> 'CANCELLED')
BEGIN
    UPDATE doctor_availability
    SET    slot_status = 'FREE'
    WHERE  slot_id = :NEW.slot_id;
END;
/

-- Prevent booking a slot that is not FREE (defence-in-depth alongside the
-- book_appointment procedure below)
CREATE OR REPLACE TRIGGER trg_prevent_double_booking
BEFORE INSERT ON appointments
FOR EACH ROW
DECLARE
    v_status doctor_availability.slot_status%TYPE;
BEGIN
    SELECT slot_status INTO v_status
    FROM   doctor_availability
    WHERE  slot_id = :NEW.slot_id;

    IF v_status <> 'FREE' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Selected slot is not available for booking.');
    END IF;
END;
/

/*==============================================================================
  6. STORED PROCEDURES
==============================================================================*/

-- Book an appointment end-to-end: creates the appointment row and a
-- pending payment row in one transaction.
CREATE OR REPLACE PROCEDURE book_appointment (
    p_patient_id   IN patients.patient_id%TYPE,
    p_doctor_id    IN doctors.doctor_id%TYPE,
    p_slot_id      IN doctor_availability.slot_id%TYPE,
    p_symptoms     IN VARCHAR2 DEFAULT NULL,
    p_appt_id      OUT appointments.appt_id%TYPE
) IS
    v_fee doctors.consult_fee%TYPE;
BEGIN
    p_appt_id := seq_appt_id.NEXTVAL;

    INSERT INTO appointments (appt_id, patient_id, doctor_id, slot_id, symptoms)
    VALUES (p_appt_id, p_patient_id, p_doctor_id, p_slot_id, p_symptoms);

    SELECT consult_fee INTO v_fee FROM doctors WHERE doctor_id = p_doctor_id;

    INSERT INTO payments (payment_id, appt_id, amount, payment_mode, payment_status)
    VALUES (seq_payment_id.NEXTVAL, p_appt_id, v_fee, NULL, 'PENDING');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Appointment '||p_appt_id||' booked successfully. Fee due: Rs.'||v_fee);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Booking failed: '||SQLERRM);
        RAISE;
END book_appointment;
/

-- Cancel an appointment (frees the slot via trg_slot_on_cancel)
CREATE OR REPLACE PROCEDURE cancel_appointment (
    p_appt_id IN appointments.appt_id%TYPE
) IS
BEGIN
    UPDATE appointments
    SET    appt_status = 'CANCELLED'
    WHERE  appt_id = p_appt_id AND appt_status = 'CONFIRMED';

    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No confirmed appointment found with ID '||p_appt_id);
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Appointment '||p_appt_id||' cancelled and slot released.');
    END IF;
END cancel_appointment;
/

-- Generate a video consultation link once payment is confirmed
CREATE OR REPLACE PROCEDURE start_video_consultation (
    p_appt_id IN appointments.appt_id%TYPE
) IS
    v_status payments.payment_status%TYPE;
BEGIN
    SELECT payment_status INTO v_status FROM payments WHERE appt_id = p_appt_id;

    IF v_status <> 'PAID' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Cannot start consultation - payment not completed.');
    END IF;

    INSERT INTO video_consultations (video_id, appt_id, meeting_link, call_status)
    VALUES (seq_video_id.NEXTVAL, p_appt_id,
            'https://teledoc-meet.example.com/room/'||p_appt_id, 'SCHEDULED');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Video consultation link generated for appointment '||p_appt_id);
END start_video_consultation;
/

/*==============================================================================
  7. FUNCTIONS
==============================================================================*/

-- Average rating for a given doctor (returns NULL if no reviews yet)
CREATE OR REPLACE FUNCTION get_doctor_avg_rating (
    p_doctor_id IN doctors.doctor_id%TYPE
) RETURN NUMBER IS
    v_avg NUMBER;
BEGIN
    SELECT ROUND(AVG(r.rating),2) INTO v_avg
    FROM   reviews r
    JOIN   appointments a ON r.appt_id = a.appt_id
    WHERE  a.doctor_id = p_doctor_id;

    RETURN v_avg;
END get_doctor_avg_rating;
/

-- Count how many FREE slots a doctor has from today onward
CREATE OR REPLACE FUNCTION get_available_slot_count (
    p_doctor_id IN doctors.doctor_id%TYPE
) RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM   doctor_availability
    WHERE  doctor_id = p_doctor_id
    AND    slot_status = 'FREE'
    AND    slot_date >= TRUNC(SYSDATE);

    RETURN v_count;
END get_available_slot_count;
/

/*==============================================================================
  8. DEMO EXECUTION - book two sample appointments end-to-end
==============================================================================*/
DECLARE
    v_appt1 appointments.appt_id%TYPE;
    v_appt2 appointments.appt_id%TYPE;
    v_slot1 doctor_availability.slot_id%TYPE;
    v_slot2 doctor_availability.slot_id%TYPE;
BEGIN
    SELECT slot_id INTO v_slot1 FROM doctor_availability
    WHERE doctor_id = 2001 AND slot_status = 'FREE' AND ROWNUM = 1;

    SELECT slot_id INTO v_slot2 FROM doctor_availability
    WHERE doctor_id = 2002 AND slot_status = 'FREE' AND ROWNUM = 1;

    book_appointment(1001, 2001, v_slot1, 'Fever and body ache', v_appt1);
    book_appointment(1002, 2002, v_slot2, 'Chest discomfort, needs cardiology review', v_appt2);

    -- Simulate payment completion for appt1, then start its video call
    UPDATE payments SET payment_status = 'PAID', payment_mode = 'UPI', paid_on = SYSDATE
    WHERE appt_id = v_appt1;
    COMMIT;

    start_video_consultation(v_appt1);

    -- Mark appt1 completed and leave a review
    UPDATE appointments SET appt_status = 'COMPLETED' WHERE appt_id = v_appt1;
    INSERT INTO reviews (review_id, appt_id, rating, review_text)
    VALUES (seq_review_id.NEXTVAL, v_appt1, 5, 'Very helpful and quick consultation.');
    COMMIT;

    -- Cancel appt2 as a demo of the cancellation flow
    cancel_appointment(v_appt2);
END;
/

/*==============================================================================
  9. SAMPLE REPORTS (run these anytime to explore the data)
==============================================================================*/
PROMPT ===== Upcoming Confirmed Appointments =====
SELECT * FROM vw_upcoming_appointments;

PROMPT ===== Doctor Ratings =====
SELECT * FROM vw_doctor_ratings ORDER BY avg_rating DESC NULLS LAST;

PROMPT ===== Doctor Revenue =====
SELECT * FROM vw_doctor_revenue ORDER BY total_revenue DESC;

PROMPT ===== All Appointments with Status =====
SELECT appt_id, patient_id, doctor_id, appt_status, booked_on FROM appointments ORDER BY appt_id;

PROMPT ===== Free Slot Count Per Doctor (using function) =====
SELECT doctor_id, full_name, get_available_slot_count(doctor_id) AS free_slots
FROM   doctors ORDER BY doctor_id;

/*==============================================================================
  END OF SCRIPT
==============================================================================*/
