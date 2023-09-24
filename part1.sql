-- DROP DATABASE info_21;

CREATE DATABASE info_21;
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE IF NOT EXISTS peers
(
    nickname VARCHAR PRIMARY KEY,
    birthday DATE NOT NULL
);

INSERT INTO peers (nickname, birthday)
VALUES ('karim', '2003-05-31'),
       ('naruto', '1999-01-01'),
       ('terminator', '1950-01-01'),
       ('tyuuki', '2003-05-31'),
       ('drumfred', '1995-10-11'),
       ('meganfox', '1986-05-16'),
       ('evaelfie', '1997-01-01'),
       ('leeroy', '1997-02-09');

CREATE TABLE IF NOT EXISTS tasks
(
    title       VARCHAR PRIMARY KEY,
    parent_task VARCHAR DEFAULT NULL REFERENCES tasks (title),
    max_xp      INTEGER
);

INSERT INTO tasks (title, parent_task, max_xp)
VALUES ('C2_SimpleBashUtils', NULL, 250),
       ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
       ('C4_s21_math', 'C2_SimpleBashUtils', 300),
       ('C5_s21_decimal', 'C2_SimpleBashUtils', 350),
       ('C6_s21_matrix', 'C2_SimpleBashUtils', 200),
       ('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
       ('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
       ('DO1_Linux', 'C3_s21_string+', 300),
       ('DO2_LinuxMonitoring v2.0', 'DO1_Linux', 350);

CREATE TABLE IF NOT EXISTS checks
(
    id   BIGSERIAL PRIMARY KEY,
    peer VARCHAR NOT NULL REFERENCES peers (nickname),
    task VARCHAR NOT NULL REFERENCES tasks (title),
    date DATE    NOT NULL
);

INSERT INTO checks (peer, task, date)
VALUES ('karim', 'C2_SimpleBashUtils', '2022-01-02'),
       ('karim', 'C3_s21_string+', '2022-01-02'),
       ('karim', 'C4_s21_math', '2022-01-02'),
       ('karim', 'C5_s21_decimal', '2022-01-02'),
       ('drumfred', 'C5_s21_decimal', '2022-01-01'),
       ('drumfred', 'C6_s21_matrix', '2022-01-01'),
       ('drumfred', 'C7_SmartCalc_v1.0', '2022-01-01'),
       ('naruto', 'C2_SimpleBashUtils', '2022-01-01'),
       ('naruto', 'C2_SimpleBashUtils', '2022-01-01'),
       ('terminator', 'C7_SmartCalc_v1.0', '2022-01-01'),
       ('terminator', 'C8_3DViewer_v1.0', '2022-01-01'),
       ('meganfox', 'C6_s21_matrix', '2022-01-02'),
       ('evaelfie', 'C3_s21_string+', '2022-01-01'),
       ('evaelfie', 'C4_s21_math', '2022-01-01'),
       ('karim', 'DO1_Linux', '2022-01-02'),
       ('karim', 'C6_s21_matrix', '2022-01-02'),
       ('karim', 'C7_SmartCalc_v1.0', '2022-01-02'),
       ('karim', 'C8_3DViewer_v1.0', '2022-01-02'),
       ('karim', 'DO1_Linux', '2022-01-02');


CREATE TYPE CHECK_STATUS AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE IF NOT EXISTS p2p
(
    id            BIGSERIAL PRIMARY KEY,
    check_id      BIGINT REFERENCES checks (id),
    checking_peer VARCHAR REFERENCES peers (nickname),
    state         CHECK_STATUS NOT NULL,
    time          TIME         NOT NULL,
    UNIQUE (check_id, checking_peer, state)
);

INSERT INTO p2p (check_id, checking_peer, state, time)
VALUES (1, 'evaelfie', 'Start', '09:42'),
       (1, 'evaelfie', 'Success', '09:43'),
       (2, 'drumfred', 'Start', '12:00'),
       (2, 'drumfred', 'Success', '12:15'),
       (3, 'tyuuki', 'Start', '13:21'),
       (3, 'tyuuki', 'Success', '13:25'),
       (4, 'meganfox', 'Start', '15:55'),
       (4, 'meganfox', 'Success', '15:56'),
       (5, 'evaelfie', 'Start', '21:15'),
       (5, 'evaelfie', 'Success', '21:22'),
       (6, 'tyuuki', 'Start', '21:30'),
       (6, 'tyuuki', 'Success', '21:40'),
       (7, 'meganfox', 'Start', '21:50'),
       (7, 'meganfox', 'Success', '21:58'),
       (8, 'drumfred', 'Start', '08:50'),
       (8, 'drumfred', 'Failure', '08:52'),
       (9, 'terminator', 'Start', '09:30'),
       (9, 'terminator', 'Failure', '09:35'),
       (10, 'naruto', 'Start', '16:30'),
       (10, 'naruto', 'Success', '16:38'),
       (11, 'karim', 'Start', '17:00'),
       (11, 'karim', 'Success', '17:07'),
       (12, 'terminator', 'Start', '13:25'),
       (12, 'terminator', 'Success', '13:29'),
       (13, 'naruto', 'Start', '21:45'),
       (13, 'naruto', 'Success', '21:47'),
       (14, 'karim', 'Start', '21:59'),
       (14, 'karim', 'Failure', '22:02'),
       (15, 'terminator', 'Start', '18:25'),
       (15, 'terminator', 'Success', '18:26'),
       (16, 'drumfred', 'Start', '9:32'),
       (16, 'drumfred', 'Success', '9:36'),
       (17, 'naruto', 'Start', '9:40'),
       (17, 'naruto', 'Success', '9:45'),
       (18, 'terminator', 'Start', '9:50'),
       (18, 'terminator', 'Success', '9:55'),
       (19, 'meganfox', 'Start', '22:15'),
       (19, 'meganfox', 'Success', '22:25');


CREATE TABLE IF NOT EXISTS verter
(
    id       BIGSERIAL PRIMARY KEY,
    check_id BIGINT REFERENCES checks (id),
    state    CHECK_STATUS NOT NULL,
    time     TIME         NOT NULL,
    UNIQUE (check_id, state)
);


INSERT INTO verter (check_id, state, time)
VALUES (1, 'Success', '09:44'),
       (2, 'Success', '12:18'),
       (3, 'Success', '13:26'),
       (4, 'Success', '15:57'),
       (5, 'Success', '21:23'),
       (6, 'Success', '21:44'),
       (7, 'Success', '22:44'),
       (10, 'Success', '16:50'),
       (11, 'Failure', '17:30'),
       (12, 'Success', '13:50'),
       (13, 'Success', '21:50'),
       (16, 'Success', '9:37'),
       (17, 'Success', '9:46'),
       (18, 'Success', '10:00');

CREATE TABLE IF NOT EXISTS transferred_points
(
    id            BIGSERIAL PRIMARY KEY,
    checking_peer VARCHAR NOT NULL REFERENCES peers (nickname),
    checked_peer  VARCHAR NOT NULL REFERENCES peers (nickname),
    points_amount INTEGER DEFAULT 1 CHECK ( points_amount >= 0 )
);

INSERT INTO transferred_points (checking_peer, checked_peer, points_amount)
VALUES ('karim', 'terminator', 1),
       ('karim', 'evaelfie', 1),
       ('naruto', 'terminator', 1),
       ('naruto', 'meganfox', 1),
       ('terminator', 'karim', 1),
       ('terminator', 'meganfox', 1),
       ('terminator', 'naruto', 1),
       ('tyuuki', 'karim', 1),
       ('tyuuki', 'drumfred', 1),
       ('drumfred', 'naruto', 1),
       ('meganfox', 'drumfred', 1),
       ('evaelfie', 'karim', 1),
       ('evaelfie', 'drumfred', 1),
       ('drumfred', 'karim', 1),
       ('naruto', 'karim', 1),
       ('meganfox', 'karim', 1);


CREATE TABLE IF NOT EXISTS friends
(
    id     BIGSERIAL PRIMARY KEY,
    peer_1 VARCHAR REFERENCES peers (nickname),
    peer_2 VARCHAR REFERENCES peers (nickname),
    UNIQUE (peer_1, peer_2)
);

INSERT INTO friends (peer_1, peer_2)
VALUES ('karim', 'evaelfie'),
       ('karim', 'drumfred'),
       ('terminator', 'meganfox'),
       ('terminator', 'evaelfie'),
       ('naruto', 'terminator'),
       ('tyuuki', 'karim'),
       ('tyuuki', 'drumfred'),
       ('drumfred', 'evaelfie'),
       ('drumfred', 'meganfox'),
       ('drumfred', 'naruto'),
       ('meganfox', 'evaelfie'),
       ('meganfox', 'tyuuki');

CREATE TABLE IF NOT EXISTS recommendations
(
    id               BIGSERIAL PRIMARY KEY,
    peer             VARCHAR NOT NULL REFERENCES peers (nickname),
    recommended_peer VARCHAR NOT NULL REFERENCES peers (nickname)
);

INSERT INTO recommendations (peer, recommended_peer)
VALUES ('karim', 'evaelfie'),
       ('karim', 'drumfred'),
       ('tyuuki', 'meganfox'),
       ('tyuuki', 'naruto'),
       ('drumfred', 'meganfox'),
       ('naruto', 'karim'),
       ('terminator', 'drumfred'),
       ('terminator', 'evaelfie');

CREATE TABLE IF NOT EXISTS xp
(
    id        BIGSERIAL PRIMARY KEY,
    check_id  BIGINT REFERENCES checks (id) UNIQUE,
    xp_amount INTEGER CHECK ( xp_amount > 0 )
);

INSERT INTO xp (check_id, xp_amount)
VALUES (1, 250),
       (2, 495),
       (3, 300),
       (4, 349),
       (5, 350),
       (6, 200),
       (7, 500),
       (10, 450),
       (12, 100),
       (13, 420),
       (16, 350),
       (17, 200),
       (18, 500),
       (15, 280),
       (19, 300);

-- Добавить триггер для отслеживания даты входа и выхода(нужно что бы все происходило в один день)
CREATE TABLE IF NOT EXISTS time_tracking
(
    id    BIGSERIAL PRIMARY KEY,
    peer  VARCHAR NOT NULL REFERENCES peers (nickname),
    date  DATE    NOT NULL,
    time  TIME    NOT NULL,
    state INTEGER CHECK ( state IN (1, 2) )
);

INSERT INTO time_tracking (peer, date, time, state)
VALUES ('evaelfie', '2022-01-01', '21:30', 1),
       ('karim', '2022-01-02', '09:30', 1),
       ('naruto', '2022-01-01', '07:59', 1),
       ('terminator', '2022-01-01', '15:21', 1),
       ('drumfred', '2022-01-01', '21:00', 1),
       ('meganfox', '2022-01-02', '12:12', 1),
       ('tyuuki', '2022-01-02', '06:54', 1),
       ('evaelfie', '2022-01-01', '23:30', 2),
       ('karim', '2022-01-02', '18:32', 2),
       ('naruto', '2022-01-01', '12:01', 2),
       ('terminator', '2022-01-01', '21:30', 2),
       ('drumfred', '2022-01-01', '22:15', 2),
       ('meganfox', '2022-01-02', '18:19', 2),
       ('tyuuki', '2022-01-02', '16:38', 2),
       ('tyuuki', '2023-02-23', '14:13', 1),
       ('tyuuki', '2023-02-27', '14:31', 2),
       ('evaelfie', now()::date, '8:00', 1),
       ('evaelfie', now()::date, '12:00', 2),
       ('drumfred', now()::date, '8:00', 1),
       ('drumfred', now()::date, '15:00', 2),
       ('drumfred', now()::date, '15:30', 1),
       ('drumfred', now()::date, '19:00', 2),
       ('drumfred', now()::date, '19:30', 1),
       ('drumfred', now()::date, '23:00', 2),
       ('evaelfie', now()::date, '15:00', 1),
       ('evaelfie', now()::date, '23:30', 2),
       ('tyuuki', now()::date - interval '1 day', '08:00', 1),
       ('tyuuki', now()::date - interval '1 day', '10:00', 2),
       ('tyuuki', now()::date - interval '1 day', '10:30', 1),
       ('tyuuki', now()::date - interval '1 day', '12:00', 2),
       ('tyuuki', now()::date - interval '1 day', '12:10', 1),
       ('tyuuki', now()::date - interval '1 day', '12:20', 2),
       ('evaelfie', now()::date - interval '1 day', '10:00', 1),
       ('evaelfie', now()::date - interval '1 day', '14:00', 2),
       ('evaelfie', now()::date - interval '1 day', '15:00', 1),
       ('evaelfie', now()::date - interval '1 day', '23:30', 2),
       ('drumfred', now()::date - interval '3 day', '19:30', 1),
       ('drumfred', now()::date - interval '3 day', '23:00', 2),
       ('tyuuki', '2022-05-20', '08:00', 1),
       ('tyuuki', '2022-05-20', '12:12', 2),
       ('tyuuki', '2022-05-24', '20:00', 1),
       ('tyuuki', '2022-05-24', '23:50', 2),
       ('drumfred', '2022-10-12', '08:00', 1),
       ('drumfred', '2022-10-12', '12:12', 2),
       ('drumfred', '2022-10-13', '20:00', 1),
       ('drumfred', '2022-10-13', '23:50', 2),
       ('leeroy', '2022-02-20', '11:50', 1),
       ('leeroy', '2022-02-20', '13:50', 2);


CREATE OR REPLACE PROCEDURE export(
    table_name VARCHAR,
    source VARCHAR,
    delimiter VARCHAR(1) DEFAULT ',')
    LANGUAGE plpgsql
AS
$$
BEGIN
    EXECUTE format('COPY %I TO %L WITH DELIMITER %L CSV HEADER', table_name, source, delimiter);
END;
$$;

-- CALL export('xp', '/Users/mymac/Desktop/daily routin/platform-21/SQL2_Info21_v1.0-0/test3.csv');


CREATE OR REPLACE PROCEDURE import(
    table_name VARCHAR,
    source VARCHAR,
    delimiter VARCHAR(1) DEFAULT ',')
    LANGUAGE plpgsql
AS
$$
BEGIN
    EXECUTE format('COPY %I FROM %L WITH DELIMITER %L CSV HEADER', table_name, source, delimiter);
END;
$$;

-- CALL import('xp', '/Users/mymac/Desktop/daily routin/platform-21/SQL2_Info21_v1.0-0/test3.csv');
