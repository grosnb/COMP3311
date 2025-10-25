-- COMP3311 T2 2025 ass1.sql
--
-- Name: Jared Wong
-- Student ID: z5416500
----------------------------------------------------------------
CREATE OR REPLACE VIEW Q1 (player, born) AS
SELECT
    name,
    birthday
FROM
    Players
WHERE
    birthday = (
        SELECT
            MIN(birthday)
        FROM
            Players
    )
GROUP BY
    name,
    birthday
ORDER BY
    name;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q2 (team, country, total_matches) AS
SELECT
    id,
    country,
    (
        SELECT
            COUNT(team)
        FROM
            (
                SELECT
                    team
                FROM
                    Involves
                WHERE
                    team = id
            )
    ) AS total_matches
FROM
    Teams
ORDER BY
    total_matches DESC,
    id ASC;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q3 (player_id, player, goals_scored, first_goal_date) AS
SELECT
    p.id AS player_id,
    p.name AS player,
    COUNT(g.scored_by) AS goals_scored,
    MIN(m.played_on) AS first_goal_date
FROM
    Players AS p
    JOIN Goals AS g ON g.scored_by = p.id
    JOIN Matches AS m ON g.scored_in = m.id
GROUP BY
    p.id,
    p.name
HAVING
    COUNT(g.scored_by) > 5
ORDER BY
    goals_scored DESC,
    player ASC,
    player_id ASC;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q4 (
    player_id,
    player,
    yellow_cards,
    red_cards,
    discipline_score
) AS
SELECT
    player_id,
    player,
    yellow_cards,
    red_cards,
    (yellow_cards * 2 + red_cards * 5) AS discipline_score
FROM
    (
        SELECT
            p.id AS player_id,
            p.name AS player,
            (
                SELECT
                    COUNT(*)
                FROM
                    Cards
                WHERE
                    card_type = 'yellow'
                    AND given_to = p.id
            ) AS yellow_cards,
            (
                SELECT
                    COUNT(*)
                FROM
                    Cards
                WHERE
                    card_type = 'red'
                    AND given_to = p.id
            ) AS red_cards
        FROM
            Players AS p
    )
GROUP BY
    player_id,
    player,
    yellow_cards,
    red_cards
HAVING
    yellow_cards + red_cards > 1
ORDER BY
    discipline_score DESC,
    player ASC,
    player_id ASC;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q5 (
    match_id,
    home_team,
    away_team,
    goals_for_each_team
) AS
SELECT
    match_id,
    (
        SELECT
            country
        FROM
            Teams
        WHERE
            id = home_team
    ) AS home_team,
    (
        SELECT
            country
        FROM
            Teams
        WHERE
            id = away_team
    ) AS away_team,
    (
        SELECT
            CONCAT (home_score, '-', away_score)
    ) AS goals_for_each_team
FROM
    (
        SELECT
            sub.match_id AS match_id,
            sub.home_team AS home_team,
            sub.away_team AS away_team,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.home_team
            ) AS home_score,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.away_team
            ) AS away_score
        FROM
            Matches AS m
            JOIN (
                SELECT
                    m.id AS match_id,
                    (
                        SELECT
                            team
                        FROM
                            (
                                SELECT
                                    *
                                FROM
                                    Involves
                                WHERE
                                    match = m.id
                                    AND is_home = true
                            )
                    ) AS home_team,
                    (
                        SELECT
                            team
                        FROM
                            (
                                SELECT
                                    *
                                FROM
                                    Involves
                                WHERE
                                    match = m.id
                                    AND is_home = false
                            )
                    ) AS away_team
                FROM
                    Matches AS m
            ) AS sub ON sub.match_id = m.id
    )
GROUP BY
    match_id,
    home_team,
    away_team,
    home_score,
    away_score
HAVING
    (home_score + away_score) > 4
ORDER BY
    match_id ASC;

-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW Q6 (match_id, score, yellow, red) AS
SELECT
    match_id,
    (
        SELECT
            CONCAT (home_score, '-', away_score)
    ) AS score,
    yellow,
    red
FROM
    (
        SELECT
            sub.match_id AS match_id,
            sub.home_team AS home_team,
            sub.away_team AS away_team,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.home_team
            ) AS home_score,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.away_team
            ) AS away_score,
            (
                SELECT
                    COUNT(*)
                FROM
                    Cards
                WHERE
                    given_in = m.id
                    AND card_type = 'yellow'
            ) as yellow,
            (
                SELECT
                    COUNT(*)
                FROM
                    Cards
                WHERE
                    given_in = m.id
                    AND card_type = 'red'
            ) as red
        FROM
            Matches AS m
            JOIN (
                SELECT
                    m.id AS match_id,
                    (
                        SELECT
                            team
                        FROM
                            (
                                SELECT
                                    *
                                FROM
                                    Involves
                                WHERE
                                    match = m.id
                                    AND is_home = true
                            )
                    ) AS home_team,
                    (
                        SELECT
                            team
                        FROM
                            (
                                SELECT
                                    *
                                FROM
                                    Involves
                                WHERE
                                    match = m.id
                                    AND is_home = false
                            )
                    ) AS away_team
                FROM
                    Matches AS m
            ) AS sub ON sub.match_id = m.id
    )
GROUP BY
    match_id,
    score,
    yellow,
    red,
    home_score,
    away_score
HAVING
    yellow > 0
    AND red > 0
    AND home_score - away_score >= -1
    AND home_score - away_score <= 1
ORDER BY
    yellow + red DESC,
    match_id ASC;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q7 (
    match_id,
    winning_team,
    halftime_score,
    fulltime_score
) AS
SELECT
    match_id,
    CASE home_score > away_score
        WHEN true THEN home_team
        ELSE away_team
    END AS winning_team,
    (
        SELECT
            CONCAT (home_mid_score, '-', away_mid_score)
    ) AS halftime_score,
    (
        SELECT
            CONCAT (home_score, '-', away_score)
    ) AS fulltime_score
FROM
    (
        SELECT
            sub.match_id AS match_id,
            (
                SELECT
                    country
                FROM
                    Teams
                WHERE
                    id = sub.home_team
            ) AS home_team,
            (
                SELECT
                    country
                FROM
                    Teams
                WHERE
                    id = sub.away_team
            ) AS away_team,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.home_team
            ) AS home_score,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.away_team
            ) AS away_score,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.home_team
                    AND time_scored <= 45
            ) AS home_mid_score,
            (
                SELECT
                    COUNT(*)
                FROM
                    Goals AS g
                    JOIN Players AS p ON g.scored_by = p.id
                WHERE
                    scored_in = m.id
                    AND p.member_of = sub.away_team
                    AND time_scored <= 45
            ) AS away_mid_score
        FROM
            Matches AS m
            JOIN (
                SELECT
                    m.id AS match_id,
                    (
                        SELECT
                            team
                        FROM
                            (
                                SELECT
                                    *
                                FROM
                                    Involves
                                WHERE
                                    match = m.id
                                    AND is_home = true
                            )
                    ) AS home_team,
                    (
                        SELECT
                            team
                        FROM
                            (
                                SELECT
                                    *
                                FROM
                                    Involves
                                WHERE
                                    match = m.id
                                    AND is_home = false
                            )
                    ) AS away_team
                FROM
                    Matches AS m
            ) AS sub ON sub.match_id = m.id
    )
GROUP BY
    match_id,
    winning_team,
    halftime_score,
    fulltime_score,
    home_score,
    away_score,
    home_mid_score,
    away_mid_score
HAVING
    (
        home_mid_score > away_mid_score
        AND home_score < away_score
    )
    OR (
        home_mid_score < away_mid_score
        AND home_score > away_score
    )
ORDER BY
    match_id ASC;

----------------------------------------------------------------
CREATE OR REPLACE FUNCTION Q8(search_term text) RETURNS SETOF TEXT
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY SELECT
        player_name || ' | ' ||
        country || ' | ' ||
        position || ' | ' ||
        career_goals || ' | ' ||
        career_cards
    FROM
        (SELECT
            p.id AS player_id,
            p.name AS player_name,
            (SELECT country FROM Teams as t WHERE t.id = p.member_of) AS country,
            p.position AS position,
            (SELECT COUNT(*) FROM Goals as g WHERE g.scored_by = p.id) AS career_goals,
            (SELECT COUNT(*) FROM Cards as c WHERE c.given_to = p.id) AS career_cards
        FROM
            (SELECT * FROM Players WHERE LOWER(name) LIKE LOWER('%' || search_term || '%')) as p)
    ORDER BY
        career_goals DESC,
        player_name ASC,
        player_id ASC;
END;
$$;

----------------------------------------------------------------
CREATE OR REPLACE FUNCTION Q9(_match_id INTEGER) RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
    result TEXT = '';
    city TEXT;
    played_on DATE;
    home_team INTEGER;
    away_team INTEGER;
    home_country TEXT;
    away_country TEXT;
    home_score INTEGER;
    home_mid_score INTEGER;
    away_score INTEGER;
    away_mid_score INTEGER;
    win_country TEXT;
    event_flag BOOLEAN = false;
    rec RECORD;
BEGIN
    IF EXISTS(SELECT 1 FROM Matches WHERE id = _match_id) THEN

        SELECT
            m.city, m.played_on
        INTO
            city, played_on
        FROM Matches AS m WHERE m.id = _match_id;
        SELECT team INTO home_team FROM Involves WHERE match = _match_id AND is_home = true;
        SELECT team INTO away_team FROM Involves WHERE match = _match_id AND is_home = false;
        SELECT country INTO home_country FROM Teams AS t WHERE t.id = home_team;
        SELECT country INTO away_country FROM Teams AS t WHERE t.id = away_team;

        -- [<city>, <played_on>] <Home_Team_country> (Team <Home_Team_id>) vs <Away_Team_country> (Team <Away_Team_id>)
        result = '[' || city || ', ' || played_on || '] ' || home_country ||
            ' (Team ' || home_team || ') vs ' ||
            away_country ||
            ' (Team ' || away_team || E')\n';

        SELECT COUNT(*) INTO home_score FROM Goals AS g JOIN Players AS p ON g.scored_by = p.id WHERE scored_in = _match_id AND p.member_of = home_team;
        SELECT COUNT(*) INTO away_score FROM Goals AS g JOIN Players AS p ON g.scored_by = p.id WHERE scored_in = _match_id AND p.member_of = away_team;
        SELECT COUNT(*) INTO home_mid_score FROM Goals AS g JOIN Players AS p ON g.scored_by = p.id WHERE scored_in = _match_id AND p.member_of = home_team AND time_scored <= 45;
        SELECT COUNT(*) INTO away_mid_score FROM Goals AS g JOIN Players AS p ON g.scored_by = p.id WHERE scored_in = _match_id AND p.member_of = away_team AND time_scored <= 45;

        -- Half-time: <Home_Team_half_goals>-<Away_Team_half_goals>
        -- Full-time: <Home_Team_full_goals>-<Away_Team_full_goals>
        result = result || 'Half-time: ' || home_mid_score || '-' || away_mid_score
                || E'\nFull-time: ' || home_score || '-' || away_score || E'\n';

        FOR rec IN
            SELECT 
                g.time_scored AS event_time,
                'Goal' AS event_type,
                g.rating AS event_characteristic,
                p.name AS event_player,
                (SELECT country FROM Teams AS t WHERE p.member_of = t.id) AS event_country,
                p.position AS event_position
            FROM Goals AS g JOIN Players AS p ON g.scored_by = p.id
            WHERE
                scored_in = _match_id
            UNION ALL
            SELECT 
                c.time_given AS event_time,
                'Card' AS event_type,
                c.card_type AS event_characteristic,
                p.name AS event_player,
                (SELECT country FROM Teams AS t WHERE p.member_of = t.id) AS event_country,
                p.position AS event_position
            FROM Cards AS c JOIN Players AS p ON c.given_to = p.id
            WHERE
                given_in = _match_id
            ORDER BY
                event_time ASC,
                event_type DESC,
                event_characteristic ASC,
                event_player ASC,
                event_country ASC,
                event_position ASC
        LOOP
            -- Minute K: Goal (<GoalRating>) - <PlayerName> (<TeamCountry>, <Position>)
            -- OR
            -- Minute K: Card (<CardType>) - <PlayerName> (<TeamCountry>, <Position>)
            result = result || 'Minute ' || rec.event_time || ': ' || rec.event_type
            || ' (' || rec.event_characteristic || ') - ' || rec.event_player || ' ('
            || rec.event_country || ', ' || rec.event_position || E')\n';
            event_flag = true;
        END LOOP;

        IF event_flag = false THEN
            result = result || E'No goals or cards occurred in this match.\n';
        END IF;
        
        -- Line N+1 (Outcome Statement):
        IF home_score = away_score THEN
            result = result || E'The match ended in a draw.\n';
        ELSIF home_score > away_score THEN
            result = result || home_country || E' wins!\n';
            win_country = home_country;
        ELSE
            result = result || away_country || E' wins!\n';
            win_country = away_country;
        END IF;

        -- Line N+2 (If applicable: Win Despite Red Card):
        IF EXISTS(SELECT 1 FROM Cards AS c JOIN Players AS p ON c.given_to = p.id JOIN Teams AS t ON t.country = win_country WHERE p.member_of = t.id AND c.card_type = 'red' AND c.given_in = _match_id) THEN
            result = result || win_country || E' won despite ending up with less than 11 players!\n';
        END IF;

        -- Line N+3 (If applicable: Stunning Comeback):
        IF (home_mid_score > away_mid_score AND home_score < away_score) OR
           (home_mid_score < away_mid_score AND home_score > away_score) THEN
            result = result || E'A stunning comeback occurred!\n';
        END IF;

    ELSE
        result = 'Match ID ' || _match_id || ' not found.';
    END IF;
    RETURN result;
END;
$$;