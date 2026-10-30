/* Проект «Секреты Тёмнолесья»

 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей
 * на покупку внутриигровой валюты «райские лепестки», а также оценить
 * активность игроков при совершении внутриигровых покупок
 *
 * Автор: Смирнова Анна Дмитриевна
 * Дата: 10.09.2026
 */

-- Часть 1. Исследовательский анализ данных


-- Задача 1. Исследование доли платящих игроков


-- 1.1. Доля платящих пользователей по всем данным:
-- Рассчитываем общее количество зарегистрированных игроков,
-- количество платящих игроков и их долю.

SELECT
    COUNT(*) AS total_users,
    COUNT(*) FILTER (WHERE payer = 1) AS paying_users,
    ROUND(
        COUNT(*) FILTER (WHERE payer = 1)::NUMERIC / COUNT(*),
        4
    ) AS paying_users_share
FROM fantasy.users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Для каждой расы рассчитываем количество платящих игроков,
-- общее количество игроков и долю платящих игроков.

SELECT
    r.race,
    COUNT(*) FILTER (WHERE u.payer = 1) AS paying_users,
    COUNT(*) AS total_users,
    ROUND(
        COUNT(*) FILTER (WHERE u.payer = 1)::NUMERIC / COUNT(*),
        4
    ) AS paying_users_share
FROM fantasy.users AS u
JOIN fantasy.race AS r
    ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY paying_users_share DESC;



-- Задача 2. Исследование внутриигровых покупок


-- 2.1. Статистические показатели по полю amount:
-- Рассчитываем количество и суммарную стоимость покупок,
-- минимум, максимум, среднее значение, медиану
-- и стандартное отклонение стоимости покупки.

SELECT
    COUNT(*) AS total_purchases,
    SUM(amount) AS total_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND(AVG(amount)::NUMERIC, 2) AS avg_amount,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)::NUMERIC,
        2
    ) AS median_amount,
    ROUND(STDDEV(amount)::NUMERIC, 2) AS stddev_amount
FROM fantasy.events;


-- 2.2. Аномальные нулевые покупки:
-- Находим количество покупок с нулевой стоимостью
-- и их долю от общего количества покупок.

SELECT
    COUNT(*) FILTER (WHERE amount = 0) AS zero_purchases,
    COUNT(*) AS total_purchases,
    ROUND(
        COUNT(*) FILTER (WHERE amount = 0)::NUMERIC / COUNT(*),
        4
    ) AS zero_purchases_share
FROM fantasy.events;


-- 2.3. Популярные эпические предметы:
-- Для каждого предмета определяем количество покупок,
-- долю покупок предмета от всех покупок
-- и долю покупателей, которые хотя бы раз его приобрели.
-- Нулевые покупки исключаем.

WITH filtered_events AS (
    SELECT *
    FROM fantasy.events
    WHERE amount > 0
),

totals AS (
    SELECT
        COUNT(*) AS total_purchases,
        COUNT(DISTINCT id) AS total_buyers
    FROM filtered_events
)

SELECT
    i.game_items,
    COUNT(*) AS item_purchases,
    ROUND(
        COUNT(*)::NUMERIC / t.total_purchases,
        4
    ) AS item_purchase_share,
    ROUND(
        COUNT(DISTINCT e.id)::NUMERIC / t.total_buyers,
        4
    ) AS item_buyer_share
FROM filtered_events AS e
JOIN fantasy.items AS i
    ON e.item_code = i.item_code
CROSS JOIN totals AS t
GROUP BY
    i.game_items,
    t.total_purchases,
    t.total_buyers
ORDER BY item_purchases DESC;



-- Часть 2. Решение ad hoc-задачи


-- Задача: Зависимость активности игроков от расы персонажа:
-- Для каждой расы рассчитываем количество зарегистрированных игроков,
-- число и долю покупателей, долю платящих среди покупателей,
-- среднее количество покупок, среднюю стоимость одной покупки
-- и среднюю суммарную стоимость покупок на одного покупателя.
-- Покупки с нулевой стоимостью исключаем.

WITH users_by_race AS (
    SELECT
        race_id,
        COUNT(*) AS total_users
    FROM fantasy.users
    GROUP BY race_id
),

purchases_by_race AS (
    SELECT
        u.race_id,
        COUNT(DISTINCT u.id) AS buyers,
        COUNT(DISTINCT u.id) FILTER (WHERE u.payer = 1) AS paying_buyers,
        COUNT(*) AS total_purchases,
        SUM(e.amount) AS total_amount
    FROM fantasy.users AS u
    JOIN fantasy.events AS e
        ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
)

SELECT
    r.race,
    ur.total_users,
    COALESCE(pr.buyers, 0) AS buyers,

    ROUND(
        COALESCE(pr.buyers, 0)::NUMERIC / ur.total_users,
        4
    ) AS buyers_share,

    ROUND(
        COALESCE(pr.paying_buyers, 0)::NUMERIC
        / NULLIF(pr.buyers, 0),
        4
    ) AS paying_buyers_share,

    ROUND(
        pr.total_purchases::NUMERIC
        / NULLIF(pr.buyers, 0),
        2
    ) AS avg_purchases_per_buyer,

    ROUND(
        pr.total_amount::NUMERIC
        / NULLIF(pr.total_purchases, 0),
        2
    ) AS avg_purchase_amount,

    ROUND(
        pr.total_amount::NUMERIC
        / NULLIF(pr.buyers, 0),
        2
    ) AS avg_total_amount_per_buyer

FROM users_by_race AS ur

JOIN fantasy.race AS r
    ON ur.race_id = r.race_id

LEFT JOIN purchases_by_race AS pr
    ON ur.race_id = pr.race_id

ORDER BY avg_purchases_per_buyer DESC;