/*ЗАДАЧА 1. ВРЕМЯ АКТИВНОСТИ ОБЪЯВЛЕНИЙ*/

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),

-- Отбираем объявления без выбросов.
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (
            rooms < (SELECT rooms_limit FROM limits)
            OR rooms IS NULL
        )
        AND (
            balcony < (SELECT balcony_limit FROM limits)
            OR balcony IS NULL
        )
        AND (
            (
                ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
                AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
            )
            OR ceiling_height IS NULL
        )
),

-- Подготавливаем данные:
-- выделяем регион и категорию по времени активности объявления.
prepared_data AS (
    SELECT
        a.id,

        CASE
            WHEN c.city = 'Санкт-Петербург'
                THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS region,

        CASE
            WHEN a.days_exposition IS NULL THEN 'non category'
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            WHEN a.days_exposition > 180 THEN '181+ days'
        END AS activity_category,

        a.last_price / NULLIF(f.total_area, 0) AS price_per_sq_m,
        f.total_area,
        f.rooms,
        f.balcony,
        f.ceiling_height,
        f.floor

    FROM real_estate.advertisement AS a

    JOIN real_estate.flats AS f
        ON a.id = f.id

    JOIN real_estate.city AS c
        ON f.city_id = c.city_id

    JOIN real_estate.type AS t
        ON f.type_id = t.type_id

    WHERE a.id IN (SELECT id FROM filtered_id)
        AND t.type = 'город'
        AND a.first_day_exposition >= DATE '2015-01-01'
        AND a.first_day_exposition < DATE '2019-01-01'
)

-- Рассчитываем показатели по категориям активности
-- отдельно для Санкт-Петербурга и городов Ленинградской области.
SELECT
    region,
    activity_category,

    COUNT(*) AS advertisements_count,

    ROUND(
        COUNT(*)::numeric
        / SUM(COUNT(*)) OVER (PARTITION BY region) * 100,
        2
    ) AS advertisements_share,

    ROUND(AVG(price_per_sq_m)::numeric, 2) AS avg_price_per_sq_m,
    ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
    ROUND(AVG(rooms)::numeric, 2) AS avg_rooms,
    ROUND(AVG(balcony)::numeric, 2) AS avg_balcony,
    ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
    ROUND(AVG(floor)::numeric, 2) AS avg_floor

FROM prepared_data

GROUP BY
    region,
    activity_category

ORDER BY
    region,
    CASE activity_category
        WHEN '1-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181+ days' THEN 4
        WHEN 'non category' THEN 5
    END;


/*ЗАДАЧА 2. СЕЗОННОСТЬ ОБЪЯВЛЕНИЙ*/

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),

-- Отбираем объявления без выбросов.
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (
            rooms < (SELECT rooms_limit FROM limits)
            OR rooms IS NULL
        )
        AND (
            balcony < (SELECT balcony_limit FROM limits)
            OR balcony IS NULL
        )
        AND (
            (
                ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
                AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
            )
            OR ceiling_height IS NULL
        )
),

-- Подготавливаем данные:
-- определяем месяц публикации и дату/месяц снятия объявления.
prepared_data AS (
    SELECT
        a.id,
        a.first_day_exposition,
        a.days_exposition,

        EXTRACT(MONTH FROM a.first_day_exposition)::integer
            AS publication_month,

        CASE
            WHEN a.days_exposition IS NOT NULL
            THEN EXTRACT(
                MONTH FROM (
                    a.first_day_exposition
                    + a.days_exposition * INTERVAL '1 day'
                )
            )::integer
        END AS removal_month,

        CASE
            WHEN a.days_exposition IS NOT NULL
            THEN (
                a.first_day_exposition
                + a.days_exposition * INTERVAL '1 day'
            )
        END AS removal_date,

        a.last_price / NULLIF(f.total_area, 0) AS price_per_sq_m,
        f.total_area

    FROM real_estate.advertisement AS a

    JOIN real_estate.flats AS f
        ON a.id = f.id

    JOIN real_estate.type AS t
        ON f.type_id = t.type_id

    WHERE a.id IN (SELECT id FROM filtered_id)
        AND t.type = 'город'
        AND a.first_day_exposition >= DATE '2015-01-01'
        AND a.first_day_exposition < DATE '2019-01-01'
),

-- Статистика по месяцам публикации объявлений.
publication_stats AS (
    SELECT
        publication_month AS month,
        COUNT(*) AS publication_count,

        ROUND(
            AVG(price_per_sq_m)::numeric,
            2
        ) AS publication_avg_price_per_sq_m,

        ROUND(
            AVG(total_area)::numeric,
            2
        ) AS publication_avg_area

    FROM prepared_data

    GROUP BY publication_month
),

-- Статистика по месяцам снятия объявлений.
removal_stats AS (
    SELECT
        removal_month AS month,
        COUNT(*) AS removal_count,

        ROUND(
            AVG(price_per_sq_m)::numeric,
            2
        ) AS removal_avg_price_per_sq_m,

        ROUND(
            AVG(total_area)::numeric,
            2
        ) AS removal_avg_area

    FROM prepared_data

    WHERE days_exposition IS NOT NULL
        AND removal_date >= DATE '2015-01-01'
        AND removal_date < DATE '2019-01-01'

    GROUP BY removal_month
),

-- Формируем список всех 12 месяцев.
months AS (
    SELECT generate_series(1, 12) AS month
)

-- Объединяем статистику публикаций и снятий в одну таблицу.
SELECT
    m.month,

    CASE m.month
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS month_name,

    p.publication_count,
    p.publication_avg_price_per_sq_m,
    p.publication_avg_area,

    r.removal_count,
    r.removal_avg_price_per_sq_m,
    r.removal_avg_area

FROM months AS m

LEFT JOIN publication_stats AS p
    ON m.month = p.month

LEFT JOIN removal_stats AS r
    ON m.month = r.month

ORDER BY m.month;