-- 1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде
-- Ник пира 1, ник пира 2, количество переданных пир поинтов.
-- Количество отрицательное, если пир 2 получил от пира 1 больше поинтов.

CREATE OR REPLACE FUNCTION fnc_transferred_points_table()
    RETURNS TABLE
            (
                peer1         VARCHAR,
                peer2         VARCHAR,
                points_amount INTEGER
            )
    LANGUAGE sql
AS
$$
SELECT t.checking_peer,
       t.checked_peer,
       sum(t.points_amount)::INTEGER AS points_amount
FROM ((SELECT tp1.checking_peer,
              tp1.checked_peer,
              tp1.points_amount
       FROM transferred_points tp1
                LEFT JOIN transferred_points tp2 ON tp1.checking_peer = tp2.checked_peer
           AND tp1.checked_peer = tp2.checking_peer
       WHERE tp2.id IS NULL)
      UNION ALL
      (SELECT tp1.checking_peer,
              tp1.checked_peer,
              tp1.points_amount - tp2.points_amount AS points_amount
       FROM transferred_points tp1
                LEFT JOIN transferred_points tp2 ON tp1.checking_peer = tp2.checked_peer
           AND tp1.checked_peer = tp2.checking_peer
       WHERE tp2.checking_peer IS NOT NULL
         AND tp1.id > tp2.id)) t
GROUP BY t.checking_peer, t.checked_peer;
$$;

-- SELECT *
-- FROM fnc_transferred_points_table();


-- 2) Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
-- В таблицу включать только задания, успешно прошедшие проверку (определять по таблице Checks).
-- Одна задача может быть успешно выполнена несколько раз. В таком случае в таблицу включать все успешные проверки.

CREATE OR REPLACE FUNCTION fnc_success_tasks()
    RETURNS TABLE
            (
                peer VARCHAR,
                task VARCHAR,
                xp   INTEGER
            )
    LANGUAGE sql
AS
$$
SELECT c.peer                                AS peer,
       substring(c.task from '[A-Z]*[0-9]*') AS task,
       x.xp_amount                           AS xp
FROM checks AS c
         JOIN xp x on c.id = x.check_id
         LEFT JOIN verter v on c.id = v.check_id
WHERE v.state = 'Success'
   OR v.state IS NULL;
$$;

-- SELECT *
-- FROM fnc_success_tasks();


-- 3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня
-- Параметры функции: день, например 12.05.2022.
-- Функция возвращает только список пиров.

CREATE OR REPLACE FUNCTION fnc_in_out(enter_date DATE DEFAULT null)
    RETURNS TABLE
            (
                name VARCHAR
            )
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF (enter_date IS NULL)
    THEN
        RAISE EXCEPTION 'Необходимо указать дату';
    ELSE
        RETURN QUERY (SELECT tt.peer AS name
                      FROM (SELECT *
                            FROM time_tracking tt1
                            WHERE state = 2) t
                               RIGHT JOIN time_tracking tt ON t.peer = tt.peer AND t.date = tt.date
                      WHERE t.peer IS NULL
                        AND tt.date = enter_date);
    END IF;
END
$$;

-- SELECT * FROM fnc_in_out('2023-02-23'); --tyuuki
-- SELECT * FROM fnc_in_out('2023-02-26'); --null


-- 4) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
-- Результат вывести отсортированным по изменению числа поинтов.
-- Формат вывода: ник пира, изменение в количество пир поинтов

CREATE OR REPLACE PROCEDURE change_peer_points(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT t.checking_peer AS peer,
               sum(sum)        AS points_change
        FROM (SELECT tp.checking_peer,
                     sum(tp.points_amount) AS sum
              FROM transferred_points tp
              GROUP BY tp.checking_peer
              UNION
              SELECT tp.checked_peer            AS peer,
                     sum(-1 * tp.points_amount) AS sum
              FROM transferred_points tp
              GROUP BY tp.checked_peer) t
        GROUP BY t.checking_peer
        ORDER BY points_change DESC;

END;
$$;

-- BEGIN;
-- CALL change_peer_points();
-- FETCH ALL IN "ref";
-- END;


-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
-- Результат вывести отсортированным по изменению числа поинтов.
-- Формат вывода: ник пира, изменение в количество пир поинтов

CREATE OR REPLACE PROCEDURE change_peer_points_on_another_func(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT t.peer1              AS peer,
               sum(t.points_change) AS points_change
        FROM ((SELECT f.peer1,
                      sum(f.points_amount) AS points_change
               FROM fnc_transferred_points_table() f
               GROUP BY f.peer1)
              UNION
              (SELECT f.peer2,
                      sum(-1 * f.points_amount) AS points_change
               FROM fnc_transferred_points_table() f
               GROUP BY f.peer2)) t
        GROUP BY t.peer1
        ORDER BY points_change DESC;
END;
$$;

-- BEGIN;
-- CALL change_peer_points_on_another_func();
-- FETCH ALL IN "ref";
-- END;


-- 6) Определить самое часто проверяемое задание за каждый день
-- При одинаковом количестве проверок каких-то заданий в определенный день, вывести их все.
-- Формат вывода: день, название задания

CREATE OR REPLACE PROCEDURE most_checks_on_day(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT t.date,
               t.task
        FROM (SELECT date,
                     substring(task from '[A-Z]*[0-9]*') AS task,
                     count(task)                         AS count
              FROM checks
              GROUP BY date, task) AS t
                 JOIN (SELECT date,
                              max(t.count) AS max
                       FROM (SELECT date,
                                    substring(task from '[A-Z]*[0-9]*') AS task,
                                    count(task)                         AS count
                             FROM checks
                             GROUP BY date, task) AS t
                       GROUP BY date) a ON t.date = a.date
        WHERE t.count = a.max
        ORDER BY t.count DESC;
END;
$$;

-- BEGIN;
-- CALL most_checks_on_day();
-- FETCH ALL IN "ref";
-- END;


-- 7) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
-- Параметры процедуры: название блока, например "CPP".
-- Результат вывести отсортированным по дате завершения.
-- Формат вывода: ник пира, дата завершения блока (т.е. последнего выполненного задания из этого блока)

CREATE OR REPLACE PROCEDURE block_success(block_name VARCHAR, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT peer,
               MAX(t.date) AS day
        FROM (SELECT title,
                     peer,
                     c.date
              FROM tasks
                       LEFT JOIN checks c on tasks.title = c.task
                       JOIN xp x on c.id = x.check_id
              WHERE block_name IN (SUBSTRING(title FROM '[A-Z]*'))
              GROUP BY title, peer, c.date) AS t
        GROUP BY peer
        HAVING COUNT(title) = (SELECT COUNT(title)
                               FROM tasks
                               WHERE block_name IN (SUBSTRING(title FROM '[A-Z]*')))
        ORDER BY day DESC;
END;
$$;

---- karim
-- BEGIN;
-- CALL block_success('C');
-- FETCH ALL IN "ref";
-- END;

---- null
-- BEGIN;
-- CALL block_success('DO');
-- FETCH ALL IN "ref";
-- END;


-- 8) Определить, к какому пиру стоит идти на проверку каждому обучающемуся
-- Определять нужно исходя из рекомендаций друзей пира, т.е. нужно найти пира, проверяться у которого рекомендует наибольшее число друзей.
-- Формат вывода: ник пира, ник найденного проверяющего

CREATE OR REPLACE PROCEDURE find_best_peer(ref REFCURSOR DEFAULT 'ref')
    language plpgsql
AS
$$
BEGIN
    OPEN ref FOR WITH agg AS (SELECT peer1,
                                     recommended_peer,
                                     count(*) AS count
                              FROM ((SELECT f.peer_1 AS peer1,
                                            r.recommended_peer
                                     FROM friends f
                                              JOIN recommendations r
                                                   ON r.peer = f.peer_2 AND f.peer_1 != r.peer AND
                                                      f.peer_1 != r.recommended_peer)
                                    UNION ALL
                                    (SELECT f.peer_2 AS peer1,
                                            r.recommended_peer
                                     FROM friends f
                                              JOIN recommendations r
                                                   ON r.peer = f.peer_1 AND f.peer_2 != r.peer AND
                                                      f.peer_2 != r.recommended_peer)) t
                              GROUP BY peer1, recommended_peer)
                 SELECT peer1                 AS peer,
                        max(recommended_peer) AS recommended_peer
                 FROM agg a1
                 WHERE count = (SELECT max(count)
                                FROM agg a2
                                WHERE a1.peer1 = a2.peer1)
                 GROUP BY peer1;
END
$$;

-- BEGIN;
-- CALL find_best_peer();
-- FETCH ALL IN "ref";
-- END;


-- 9) Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
--
-- Пир считается приступившим к блоку, если он проходил хоть одну проверку любого задания из этого блока (по таблице Checks)
-- Параметры процедуры: название блока 1, например SQL, название блока 2, например A.
-- Формат вывода: процент приступивших только к первому блоку,
-- процент приступивших только ко второму блоку, процент приступивших к обоим, процент не приступивших ни к одному

CREATE OR REPLACE PROCEDURE stat_of_peers(block_1 VARCHAR, block_2 VARCHAR, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
DECLARE
    num_of_peers NUMERIC;
BEGIN
    num_of_peers := (SELECT count(*) FROM peers);
    OPEN ref FOR
        WITH agg AS (SELECT p.nickname,
                            count(CASE WHEN c.task SIMILAR TO format('%s[0-9]_%%', block_1) THEN 1 END) AS b1,
                            count(CASE WHEN c.task SIMILAR TO format('%s[0-9]_%%', block_2) THEN 1 END) AS b2
                     FROM peers p
                              LEFT JOIN checks c on p.nickname = c.peer
                     GROUP BY p.nickname)
        SELECT round(count(CASE WHEN a.b1 != 0 AND a.b2 = 0 THEN 1 END) / num_of_peers * 100, 2) AS started_block_1,
               round(count(CASE WHEN a.b1 = 0 AND a.b2 != 0 THEN 1 END) / num_of_peers * 100, 2) AS started_block_2,
               round(count(CASE WHEN a.b1 != 0 AND a.b2 != 0 THEN 1 END) / num_of_peers * 100,
                     2)                                                                          AS started_both_blocks,
               round(count(CASE WHEN a.b1 = 0 AND a.b2 = 0 THEN 1 END) / num_of_peers * 100,
                     2)                                                                          AS didnt_start_any_block
        FROM agg a;
END
$$;

-- BEGIN;
-- CALL stat_of_peers('C', 'DO');
-- FETCH ALL IN "ref";
-- COMMIT;

-- BEGIN;
-- CALL stat_of_peers('DO', 'C');
-- FETCH ALL IN "ref";
-- COMMIT;

-- BEGIN;
-- CALL stat_of_peers('DO', 'CPP');
-- FETCH ALL IN "ref";
-- COMMIT;


-- 10) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
-- Также определите процент пиров, которые хоть раз проваливали проверку в свой день рождения.
-- Формат вывода: процент успехов в день рождения, процент неуспехов в день рождения

CREATE OR REPLACE PROCEDURE checks_birthday(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR WITH agg AS (SELECT *
                              FROM (SELECT p.nickname,
                                           c.id,
                                           extract(MONTH FROM p.birthday) || '-' || extract(DAY FROM p.birthday) AS birthday,
                                           extract(MONTH FROM c.date) || '-' || extract(DAY FROM c.date)         AS check_date
                                    FROM peers p
                                             JOIN checks c on p.nickname = c.peer) t
                              WHERE birthday = check_date),
                      t_for_count AS (SELECT t.state,
                                             t.count,
                                             sum(t.count) OVER () AS total
                                      FROM (SELECT CASE
                                                       WHEN t.p2p_state = 'Success' AND t.v_state = 'Success'
                                                           THEN 'Success'
                                                       WHEN t.p2p_state = 'Success' AND t.v_state IS NULL
                                                           THEN 'Success'
                                                       ELSE 'Failure'
                                                       END  AS state,
                                                   count(*) AS count
                                            FROM (SELECT p.state AS p2p_state,
                                                         v.state AS v_state
                                                  FROM agg a
                                                           JOIN p2p p ON a.id = p.check_id
                                                           LEFT JOIN verter v on a.id = v.check_id
                                                  WHERE p.state = 'Success'
                                                     OR p.state = 'Failure') t
                                            GROUP BY state) t)
                 SELECT (SELECT round(count / total * 100, 2) AS successful_checks
                         FROM t_for_count
                         WHERE state = 'Success'),
                        (SELECT round(count / total * 100, 2) AS unsuccessful_checks
                         FROM t_for_count
                         WHERE state = 'Failure');
END
$$;

-- BEGIN;
-- CALL checks_birthday();
-- FETCH ALL IN "ref";
-- COMMIT;


-- 11) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
-- Параметры процедуры: названия заданий 1, 2 и 3.
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE find_peers_on_tasks(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR,
                                                ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR SELECT t.nickname AS peer
                 FROM (SELECT nickname,
                              count(CASE WHEN c.task = task1 THEN 1 END) AS first_task,
                              count(CASE WHEN c.task = task2 THEN 1 END) AS second_task,
                              count(CASE WHEN c.task = task3 THEN 1 END) AS third_task
                       FROM peers pe
                                JOIN checks c on pe.nickname = c.peer
                                JOIN p2p p on c.id = p.check_id
                                LEFT JOIN verter v on c.id = v.check_id
                       WHERE (p.state = 'Success' AND v.state = 'Success')
                          OR (p.state = 'Success' AND v.state IS NULL)
                       GROUP BY nickname) t
                 WHERE first_task != 0
                   AND second_task != 0
                   AND third_task = 0;
END
$$;

-- BEGIN;
-- CALL find_peers_on_tasks('C2_SimpleBashUtils', 'C3_s21_string+', 'DO1_Linux');
-- FETCH ALL IN "ref";
-- COMMIT; -- out-->null

-- BEGIN;
-- CALL find_peers_on_tasks('C5_s21_decimal', 'C6_s21_matrix', 'DO1_Linux');
-- FETCH ALL IN "ref";
-- COMMIT; -- out-->drumfred

-- BEGIN;
-- CALL find_peers_on_tasks('C4_s21_math', 'C3_s21_string+', 'DO2_LinuxMonitoring v2.0');
-- FETCH ALL IN "ref";
-- COMMIT; -- out-->karim


-- 12) Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей.
-- Формат вывода: название задачи, количество предшествующих

CREATE OR REPLACE PROCEDURE recur_find_task_parents(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH RECURSIVE rec AS (SELECT t1.title,
                                      0 AS number
                               FROM tasks AS t1
                               WHERE parent_task IS NULL
                               UNION
                               SELECT t2.title,
                                      r.number + 1
                               FROM tasks t2
                                        JOIN rec r ON r.title = t2.parent_task)

        SELECT substring(rec.title from '[A-Z]*[0-9]*') AS task,
               rec.number                               AS prev_count
        FROM rec;
END
$$;

-- BEGIN;
-- CALL recur_find_task_parents();
-- FETCH ALL IN "ref";
-- COMMIT;


-- 13) Найти "удачные" для проверок дни. День считается "удачным", если в нем есть хотя бы N идущих подряд успешных проверки
-- Параметры процедуры: количество идущих подряд успешных проверок N.
-- Временем проверки считать время начала P2P этапа.
-- Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных.
-- При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального.

CREATE OR REPLACE FUNCTION fnc_find_success_dates(n_days INTEGER)
    RETURNS SETOF DATE
    LANGUAGE plpgsql
AS
$$
DECLARE
    f_date DATE;
    count  INTEGER;
    max    INTEGER;
    iter   INTEGER;
BEGIN
    CREATE OR REPLACE TEMPORARY VIEW table_1 AS
    SELECT *
    FROM (SELECT t.date,
                 t.state,
                 row_number() OVER () AS row_id
          FROM (SELECT c.date,
                       CASE
                           WHEN p.state = 'Success' AND v.state IS NULL
                               THEN 'Success'
                           WHEN v.state = 'Failure' OR p.state = 'Failure'
                               THEN 'Failure'
                           ELSE
                               'Success'
                           END AS state
                FROM checks c
                         JOIN p2p p on c.id = p.check_id
                         LEFT JOIN verter v on c.id = v.check_id
                WHERE p.state != 'Start'
                ORDER BY c.date, p.time) t) t;
    IF (n_days <= 0)
    THEN
        n_days := 1;
    END IF;
    count := 0;
    iter := 1;
    max = (SELECT count(*)
           FROM table_1);
    f_date = (SELECT date
              FROM table_1
              LIMIT 1);
    WHILE iter < max
        LOOP
            IF ((SELECT t.date
                 FROM table_1 t
                 WHERE t.date = f_date
                   AND row_id = iter
                   AND t.state = 'Success') IS NOT NULL)
            THEN
                count := count + 1;
            ELSEIF ((SELECT t.date
                     FROM table_1 t
                     WHERE t.date != f_date
                       AND row_id = iter
                       AND t.state = 'Success') IS NOT NULL)
            THEN
                count := 1;
            ELSE
                count := 0;
            END IF;

            IF ((SELECT t.date FROM table_1 t WHERE row_id = iter) != f_date)
            THEN
                f_date := (SELECT t.date FROM table_1 t WHERE row_id = iter);
            END IF;

            IF (count = n_days)
            THEN
                RETURN NEXT (SELECT date FROM table_1 WHERE row_id = iter);
                WHILE iter < max
                    LOOP
                        IF ((SELECT t.date FROM table_1 t WHERE row_id = iter) != f_date)
                        THEN
                            f_date := (SELECT t.date FROM table_1 t WHERE row_id = iter);
                            count := 0;
                            EXIT;
                        ELSE
                            iter := iter + 1;
                        END IF;
                    END LOOP;
            END IF;
            iter := iter + 1;
        END LOOP;
END
$$;

CREATE OR REPLACE PROCEDURE find_best_days(n_days INTEGER, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR (SELECT *
                  FROM fnc_find_success_dates(n_days));
END
$$;

-- BEGIN;
-- CALL find_best_days(5);
-- FETCH ALL IN "ref";
-- COMMIT;

-- BEGIN;
-- CALL find_best_days(2);
-- FETCH ALL IN "ref";
-- COMMIT;


-- 14) Определить пира с наибольшим количеством XP
-- Формат вывода: ник пира, количество XP

CREATE OR REPLACE PROCEDURE find_best_peer_on_xp(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT peer,
               SUM(xp) AS xp
        FROM (SELECT nickname       AS peer,
                     title          AS title,
                     MAX(xp_amount) AS xp
              FROM peers
                       JOIN checks c on peers.nickname = c.peer
                       JOIN p2p p on c.id = p.check_id
                       JOIN xp x on c.id = x.check_id
                       JOIN tasks ON c.task = tasks.title
              GROUP BY nickname, title) AS t
        GROUP BY peer
        ORDER BY xp DESC
        LIMIT 1;
END
$$;

-- BEGIN;
-- CALL find_best_peer_on_xp();
-- FETCH ALL IN "ref";
-- COMMIT;


-- 15) Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
-- Параметры процедуры: время, количество раз N.
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE peer_time_track(numbers_of_visits INTEGER, visit_time TIME, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT DISTINCT peer
        FROM (SELECT peer        AS peer,
                     time        AS time,
                     count(peer) AS numbers_of_visits
              FROM time_tracking
              WHERE state = 1
              GROUP BY peer, time) AS t
        WHERE t.numbers_of_visits >= peer_time_track.numbers_of_visits
          AND time < visit_time;
END
$$;

-- BEGIN;
-- CALL peer_time_track(1, '19:30:00');
-- FETCH ALL IN "ref";
-- COMMIT;

-- BEGIN;
-- CALL peer_time_track(2, '10:30:00');
-- FETCH ALL IN "ref";
-- COMMIT;


-- 16) Определить пиров, выходивших за последние N дней из кампуса больше M раз
-- Параметры процедуры: количество дней N, количество раз M.
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE find_peers_exit_n_days_m_times(n_days INTEGER, n_times INTEGER, ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR SELECT t.peer
                 FROM (SELECT peer,
                              count(*) AS count
                       FROM time_tracking tt
                       WHERE tt.state = 2
                         AND tt.date BETWEEN (now()::date - interval '1 day' * n_days)::date AND now()::date
                       GROUP BY peer) t
                 WHERE count > n_times;
END
$$;

-- BEGIN;
-- CALL find_peers_exit_n_days_m_times(100, 2);
-- FETCH ALL IN "ref";
-- COMMIT;

-- BEGIN;
-- CALL find_peers_exit_n_days_m_times(1, 3);
-- FETCH ALL IN "ref";
-- COMMIT;


-- 17) Определить для каждого месяца процент ранних входов
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время (будем называть это общим числом входов).
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов).
-- Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов.
-- Формат вывода: месяц, процент ранних входов

CREATE OR REPLACE FUNCTION fnc_make_text_month(number_of_month INTEGER)
    RETURNS VARCHAR
    LANGUAGE plpgsql
AS
$$
DECLARE
    months VARCHAR[] := '{"January", "February", "March", "April", "May",' ||
                        '"June", "July", "August", "September", "October", "November", "December"}';
BEGIN
    RETURN months[number_of_month];
END;
$$;

CREATE OR REPLACE FUNCTION fnc_sum_enters()
    RETURNS TABLE
            (
                month INTEGER,
                count INTEGER
            )
    LANGUAGE plpgsql
AS
$$
DECLARE
    total_count INTEGER;
BEGIN
    FOR i IN 1..12
        LOOP
            total_count := 0;
            total_count := count(*)
                           FROM time_tracking tt
                                    JOIN peers p on p.nickname = tt.peer
                           WHERE date_part('month', tt.date) = i
                             AND date_part('month', p.birthday) = i
                             AND tt.state = 1;

            total_count := total_count + count(*)
                           FROM time_tracking tt
                                    JOIN peers p on p.nickname = tt.peer
                           WHERE date_part('month', tt.date) = i
                             AND date_part('month', p.birthday) = i
                             AND tt.state = 1
                             AND tt.time < '12:00';

            RETURN QUERY (SELECT i, total_count);
        END LOOP;
END
$$;

CREATE OR REPLACE FUNCTION fnc_calculate_enters_percent()
    RETURNS TABLE
            (
                month         VARCHAR,
                early_entries NUMERIC
            )
    LANGUAGE plpgsql
AS
$$
DECLARE
    total_entries INTEGER;
BEGIN
    total_entries := sum(count)
                     FROM fnc_sum_enters();

    FOR i IN 1..12
        LOOP
            RETURN QUERY (SELECT fnc_make_text_month(i)                                             AS month,
                                 round((count::numeric * 100::numeric) / total_entries::numeric, 2) AS early_entries
                          FROM fnc_sum_enters() t
                          WHERE t.month = i);
        END LOOP;
END
$$;

CREATE OR REPLACE PROCEDURE find_early_entries(ref REFCURSOR DEFAULT 'ref')
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT *
        FROM fnc_calculate_enters_percent();
END
$$;

-- BEGIN;
-- CALL find_early_entries();
-- FETCH ALL IN "ref";
-- COMMIT;