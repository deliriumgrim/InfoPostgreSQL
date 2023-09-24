-- 1) Написать процедуру добавления P2P проверки
-- Параметры: ник проверяемого, ник проверяющего, название задания, статус P2P проверки, время.
-- Если задан статус "начало", добавить запись в таблицу Checks (в качестве даты использовать сегодняшнюю).
-- и в качестве проверки указать только что добавленную запись, иначе указать проверку с незавершенным P2P этапом.
-- Добавить запись в таблицу P2P.

CREATE OR REPLACE PROCEDURE insert_p2p_check(peer_checked_name VARCHAR,
                                             peer_checking_name VARCHAR,
                                             task_title VARCHAR,
                                             state_of_p2p_check CHECK_STATUS,
                                             time_t TIME)
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF (peer_checking_name = peer_checked_name)
    THEN
        RAISE EXCEPTION 'Проверяющий не может быть равен проверяемому';
    ELSEIF (state_of_p2p_check = 'Start')
    THEN
        INSERT INTO checks (peer, task, date)
        VALUES (peer_checked_name, task_title, now()::DATE);
        INSERT INTO p2p (check_id, checking_peer, state, time)
        VALUES ((SELECT MAX(id)
                 FROM checks), peer_checking_name,
                state_of_p2p_check,
                time_t);
    ELSE
        INSERT INTO p2p (check_id, checking_peer, state, time)
        VALUES ((SELECT MAX(id)
                 FROM checks), peer_checking_name,
                state_of_p2p_check,
                time_t);
    END IF;
END
$$;

-- CALL insert_p2p_check('drumfred', 'evaelfie', 'C4_s21_math', 'Start', '21:37');
-- CALL insert_p2p_check('drumfred', 'evaelfie', 'C4_s21_math', 'Success', '21:39');


-- 2) Написать процедуру добавления проверки Verter'ом
-- Параметры: ник проверяемого, название задания, статус проверки Verter'ом, время.
-- Добавить запись в таблицу Verter (в качестве проверки указать проверку соответствующего задания с самым поздним (по времени) успешным P2P этапом)

CREATE OR REPLACE PROCEDURE insert_verter_check(peer_checked_name VARCHAR,
                                                task_title VARCHAR,
                                                state_of_check CHECK_STATUS,
                                                time_t TIME)
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF ((SELECT count(c.id)
         FROM checks AS c
                  JOIN p2p p on c.id = p.check_id
         WHERE c.peer = peer_checked_name
           AND c.task = task_title
           AND p.state = 'Success') = 0)
    THEN
        RAISE EXCEPTION 'Проверка не находится в статусе Success';
    ELSE
        INSERT INTO verter (check_id, state, time)
        VALUES ((SELECT c.id
                 FROM checks AS c
                          JOIN p2p AS p ON c.id = p.check_id
                 WHERE c.peer = peer_checked_name
                   AND c.task = task_title
                   AND p.state = 'Success'
                 ORDER BY p.time DESC
                 LIMIT 1), state_of_check, time_t);
    END IF;
END
$$;

--1 тест Должен быть exception т.к. naruto завалил п2п
-- CALL insert_verter_check('naruto', 'C2_SimpleBashUtils', 'Success', now()::TIME);
-- CALL insert_verter_check('karim', 'C4_s21_math', 'Failure', now()::TIME);


-- 3) Написать триггер: после добавления записи со статутом "начало" в таблицу P2P,
-- изменить соответствующую запись в таблице TransferredPoints

CREATE OR REPLACE FUNCTION fnc_transferred_points_update_points() RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF (NEW.state = 'Start')
    THEN
        UPDATE transferred_points
        SET points_amount = points_amount + 1
        WHERE checking_peer = NEW.checking_peer
          AND checked_peer = (SELECT peer
                              FROM checks AS c
                                       JOIN p2p p on c.id = p.check_id
                              WHERE NEW.check_id = c.id
                              LIMIT 1);
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER trg_transferred_points_update_points
    AFTER INSERT
    ON p2p
    FOR EACH ROW
EXECUTE FUNCTION fnc_transferred_points_update_points();

-- --transferred_points has changed
-- INSERT INTO p2p (check_id, checking_peer, state, time)
-- VALUES (3, 'drumfred', 'Start', '21:30');
-- --transferred_points hasn't changed
-- INSERT INTO p2p (check_id, checking_peer, state, time)
-- VALUES (3, 'drumfred', 'Success', '21:35');


-- 4) Написать триггер: перед добавлением записи в таблицу XP, проверить корректность добавляемой записи
-- Запись считается корректной, если:
-- Количество XP не превышает максимальное доступное для проверяемой задачи
-- Поле Check ссылается на успешную проверку
-- Если запись не прошла проверку, не добавлять её в таблицу.

CREATE OR REPLACE FUNCTION fnc_xp_insert_or_update() RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF ((SELECT count(state)
         FROM p2p
         WHERE p2p.check_id = NEW.check_id
           AND p2p.state = 'Success') = 0)
    THEN
        RAISE EXCEPTION 'Проверка из таблица p2p не находится в состоянии Success';
    ELSEIF ((SELECT tasks.max_xp - NEW.xp_amount
             FROM tasks
                      JOIN checks c on tasks.title = c.task
             WHERE c.id = NEW.check_id) < 0)
    THEN
        RAISE EXCEPTION 'Количество xp превышает максимально допустимое';
    ELSE
        RETURN NULL;
    END IF;
END
$$;

CREATE OR REPLACE TRIGGER trg_xp_insert_or_update
    BEFORE INSERT
    ON xp
    FOR EACH ROW
EXECUTE FUNCTION fnc_xp_insert_or_update();

-- INSERT INTO xp (check_id, xp_amount) VALUES (14, 100); --must be failed
-- INSERT INTO xp (check_id, xp_amount) VALUES (13, 100000); --must be failed
-- INSERT INTO xp (check_id, xp_amount) VALUES (20, 299);