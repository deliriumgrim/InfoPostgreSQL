CREATE DATABASE part_4;

CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE IF NOT EXISTS account
(
    account_id BIGSERIAL PRIMARY KEY,
    login      VARCHAR,
    password   VARCHAR
);

CREATE TABLE IF NOT EXISTS user_data
(
    account_id BIGSERIAL PRIMARY KEY REFERENCES account (account_id),
    name       VARCHAR,
    age        INT
);

CREATE TABLE IF NOT EXISTS TableName1
(
    job        VARCHAR,
    car_number INT
);

CREATE TABLE IF NOT EXISTS TableName2
(
    sex          VARCHAR,
    home_address VARCHAR
);

CREATE TABLE IF NOT EXISTS _TableName2
(
    price        INT,
    thing_number INT
);

CREATE OR REPLACE FUNCTION fnc_trg1() RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    RAISE NOTICE 'Hello world1';
    RETURN NULL;
END
$$;

CREATE TRIGGER trg1
    BEFORE INSERT OR UPDATE
    ON _TableName2
    FOR EACH ROW
EXECUTE FUNCTION fnc_trg1();

CREATE OR REPLACE FUNCTION fnc_trg2() RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    RAISE NOTICE 'Hello world2';
    RETURN NULL;
END
$$;

CREATE TRIGGER trg2
    BEFORE INSERT OR UPDATE
    ON TableName2
    FOR EACH ROW
EXECUTE FUNCTION fnc_trg2();

CREATE OR REPLACE FUNCTION fnc_fibonacci(IN pstop INTEGER DEFAULT 10)
    RETURNS TABLE
            (
                fnc_result INTEGER
            )
    LANGUAGE SQL
AS
$$
WITH RECURSIVE t AS (SELECT 0 AS a, 1 AS b
                     UNION ALL
                     SELECT b,
                            a + b
                     FROM t
                     WHERE b < pstop)
SELECT a
FROM t;
$$;

CREATE OR REPLACE FUNCTION func_minimum(VARIADIC arr numeric[])
    RETURNS numeric
    LANGUAGE SQL
AS
$$
SELECT min(arr[i])
FROM generate_subscripts(arr, 1) g(i);
$$;

CREATE OR REPLACE FUNCTION func_display_table()
    RETURNS TABLE
            (
                account_id BIGINT,
                login      VARCHAR,
                password   VARCHAR
            )
    LANGUAGE sql
AS
$$
SELECT *
FROM user_data;
$$;


-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных,
-- уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.

CREATE OR REPLACE PROCEDURE substr_delete()
    LANGUAGE plpgsql
AS
$$
DECLARE
    name_table VARCHAR;
BEGIN
    FOR name_table IN SELECT table_name
                      FROM information_schema.tables
                      WHERE table_name LIKE 'tablename%'
                        AND table_schema = 'public'
        LOOP
            EXECUTE FORMAT('drop table %I cascade', name_table);
        END LOOP;
END
$$;

-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_name LIKE 'tablename%'
-- AND table_schema = 'public';

-- BEGIN;
-- CALL substr_delete();
-- COMMIT;


-- 2) Создать хранимую процедуру с выходным параметром, которая выводит список имен и параметров всех скалярных
-- SQL функций пользователя в текущей базе данных.
-- Имена функций без параметров не выводить. Имена и список параметров должны выводиться в одну строку.
-- Выходной параметр возвращает количество найденных функций.

CREATE OR REPLACE PROCEDURE numbers_of_fnc_with_params(OUT count INTEGER, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT ROUTINE_NAME, STRING_AGG(parameters.parameter_name, ',') AS parameters
        FROM information_schema.routines
                 JOIN information_schema.parameters
                      ON routines.specific_name = parameters.specific_name
        WHERE routines.specific_schema = 'public'
          AND routine_type = 'FUNCTION'
          AND parameters.parameter_name IS NOT NULL
        GROUP BY ROUTINE_NAME;

    count := (SELECT count(*) OVER ()
              FROM information_schema.routines
                       JOIN information_schema.parameters
                            ON routines.specific_name = parameters.specific_name
              WHERE routines.specific_schema = 'public'
                AND routine_type = 'FUNCTION'
                AND parameters.parameter_name IS NOT NULL
              GROUP BY ROUTINE_NAME
              LIMIT 1);

    RAISE NOTICE 'count of functions: %', count;
END;
$$;

-- BEGIN;
-- CALL numbers_of_fnc_with_params(NULL);
-- FETCH ALL FROM "ref";
-- COMMIT;


-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.

CREATE OR REPLACE PROCEDURE delete_triggers(OUT numbers_of_delete_triggers INTEGER)
    LANGUAGE plpgsql
AS
$$
DECLARE
    rec record;
BEGIN
    numbers_of_delete_triggers = 0;
    FOR rec IN
        SELECT trigger_name t_n, event_object_table e_o_t
        FROM information_schema.triggers
        GROUP BY trigger_name, event_object_table
        LOOP
            EXECUTE FORMAT('DROP TRIGGER %I ON %I CASCADE', rec.t_n, rec.e_o_t);
            numbers_of_delete_triggers = numbers_of_delete_triggers + 1;
        END LOOP;

    RAISE NOTICE 'count of delete triggers: %', numbers_of_delete_triggers;
END
$$;

-- BEGIN;
-- CALL delete_triggers(NULL);
-- COMMIT;


-- 4) Создать хранимую процедуру с входным параметром,
-- которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.

CREATE OR REPLACE PROCEDURE objects_like(IN string VARCHAR, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT *
        FROM (SELECT p.routine_name,
                     p.routine_type
              FROM information_schema.routines AS p
                       JOIN information_schema.parameters
                            ON p.specific_name = parameters.specific_name
              WHERE p.specific_schema = 'public'
                  AND (routine_type = 'FUNCTION' AND parameters.parameter_name IS NOT NULL)
                 OR routine_type = 'PROCEDURE'
              GROUP BY p.routine_name, p.routine_type) p
        WHERE p.routine_name LIKE '%' || string || '%';

END
$$;

-- BEGIN;
-- CALL objects_like('fnc');
-- FETCH ALL IN "ref";
-- COMMIT;

-- BEGIN;
-- CALL objects_like('func');
-- FETCH ALL IN "ref";
-- COMMIT;
