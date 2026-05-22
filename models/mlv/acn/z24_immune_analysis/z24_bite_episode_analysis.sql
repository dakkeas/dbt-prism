{{ config(materialized='table') }}

-- =============================================================================
-- Z24 Bite Episode Analysis
-- 
-- Animal Bite Claim  = loatype IN ('CONSULT', 'EMERGENCY')
-- Dosage Claim       = loatype IN ('PROCEDURE', 'CONSULT')
--
-- Part 1: Identify distinct animal bite incidents using a 90-day gap rule.
-- Part 2: For each bite incident, count distinct dosage dates from the bite
--          date up to (but not including) the next bite incident.
-- =============================================================================

WITH raw_data AS (
    SELECT *
    FROM {{ ref('z24_acn_datacut_2425') }}
),

-- Patient-level demographics (take most recent values)
patient_demographics AS (
    SELECT 
        maskedcardno,
        MAX(gender) AS gender,
        MAX(age) AS age,
        MAX(membershiptype) AS membershiptype,
        MAX(corpcode) AS corpcode,
        MAX(branchdesc) AS branchdesc
    FROM raw_data
    GROUP BY maskedcardno
),

-- =====================================================================
-- Classify claims
-- =====================================================================

-- Animal bite claims: target ICD codes (Z24.2, W53, W54, W55) + loatype = CONSULT or EMERGENCY
-- Deduplicated to one row per patient per day
bite_claims AS (
    SELECT 
        maskedcardno,
        CAST(admissiondate AS DATE) AS service_date
    FROM raw_data
    WHERE (
            UPPER(icdcode) = 'Z24.2'
         OR UPPER(icdcode) LIKE 'W53%'
         OR UPPER(icdcode) LIKE 'W54%'
         OR UPPER(icdcode) LIKE 'W55%'
    )
    AND UPPER(loatype) IN ('CONSULT', 'EMERGENCY')
    GROUP BY maskedcardno, CAST(admissiondate AS DATE)
),

-- Dosage claims: target ICD codes (Z24.2, W53, W54, W55) + loatype = PROCEDURE or CONSULT
-- Deduplicated to one row per patient per day
dosage_claims AS (
    SELECT 
        maskedcardno,
        CAST(admissiondate AS DATE) AS service_date,
        SUM(approved) AS approved
    FROM raw_data
    WHERE (
            UPPER(icdcode) = 'Z24.2'
         OR UPPER(icdcode) LIKE 'W53%'
         OR UPPER(icdcode) LIKE 'W54%'
         OR UPPER(icdcode) LIKE 'W55%'
    )
    AND UPPER(loatype) IN ('PROCEDURE', 'CONSULT')
    GROUP BY maskedcardno, CAST(admissiondate AS DATE)
),

-- =====================================================================
-- PART 1: Distinct Animal Bite Incidents (90-Day Gap Rule)
-- =====================================================================

-- Calculate gap in days between consecutive bite dates per patient
bite_with_gaps AS (
    SELECT 
        maskedcardno,
        service_date,
        LAG(service_date) OVER (
            PARTITION BY maskedcardno 
            ORDER BY service_date
        ) AS prev_bite_date,
        {% if target.type == 'bigquery' %}
            DATE_DIFF(
                service_date,
                LAG(service_date) OVER (
                    PARTITION BY maskedcardno 
                    ORDER BY service_date
                ),
                DAY
            ) AS days_since_prev_bite
        {% else %}
            service_date - LAG(service_date) OVER (
                PARTITION BY maskedcardno 
                ORDER BY service_date
            ) AS days_since_prev_bite
        {% endif %}
    FROM bite_claims
),

-- Assign bite incident numbers:
-- First bite = Incident #1, gap > 90 days = new incident
bite_incidents AS (
    SELECT 
        maskedcardno,
        service_date,
        prev_bite_date,
        days_since_prev_bite,
        SUM(
            CASE 
                WHEN days_since_prev_bite IS NULL 
                  OR days_since_prev_bite > 90 
                THEN 1 
                ELSE 0 
            END
        ) OVER (
            PARTITION BY maskedcardno 
            ORDER BY service_date
        ) AS bite_incident_number
    FROM bite_with_gaps
),

-- =====================================================================
-- PART 2: Dosage Counting per Bite Incident
-- =====================================================================

-- Get the earliest date for each bite incident (= episode anchor / Day 0)
-- and the next bite date to cap the dosage window
bite_episode_starts AS (
    SELECT 
        maskedcardno,
        bite_incident_number,
        MIN(service_date) AS bite_date,
        LEAD(MIN(service_date)) OVER (
            PARTITION BY maskedcardno 
            ORDER BY bite_incident_number
        ) AS next_bite_date
    FROM bite_incidents
    GROUP BY maskedcardno, bite_incident_number
),

-- Count distinct dosage dates from bite_date up to (but not including) next bite
-- For the last bite incident, counts all dosages from bite_date onward
episode_dosage_counts AS (
    SELECT 
        b.maskedcardno,
        b.bite_incident_number,
        b.bite_date,
        b.next_bite_date,
        COUNT(DISTINCT d.service_date) AS dosage_count,
        COALESCE(SUM(d.approved), 0) AS total_approved,
        MIN(d.service_date) AS first_dose_date,
        MAX(d.service_date) AS last_dose_date
    FROM bite_episode_starts b
    LEFT JOIN dosage_claims d
        ON b.maskedcardno = d.maskedcardno
        AND d.service_date >= b.bite_date
        AND (b.next_bite_date IS NULL OR d.service_date < b.next_bite_date)
    GROUP BY b.maskedcardno, b.bite_incident_number, b.bite_date, b.next_bite_date
),

-- Patient-level summary: total distinct bite incidents
patient_bite_summary AS (
    SELECT 
        maskedcardno,
        MAX(bite_incident_number) AS total_bite_incidents
    FROM bite_incidents
    GROUP BY maskedcardno
)

-- =====================================================================
-- FINAL OUTPUT: One row per patient × bite incident
-- =====================================================================
SELECT 
    e.maskedcardno,
    dm.gender,
    dm.age,
    dm.membershiptype,
    dm.corpcode,
    dm.branchdesc,
    e.bite_incident_number,
    e.bite_date,
    e.next_bite_date,
    e.dosage_count      AS doses_per_bite,
    e.total_approved,
    e.first_dose_date,
    e.last_dose_date,
    p.total_bite_incidents
FROM episode_dosage_counts e
LEFT JOIN patient_bite_summary p
    ON e.maskedcardno = p.maskedcardno
LEFT JOIN patient_demographics dm
    ON e.maskedcardno = dm.maskedcardno
ORDER BY e.maskedcardno, e.bite_incident_number
