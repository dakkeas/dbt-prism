{{ config(materialized='table') }}

-- =============================================================================
-- Z24 Dosage Detail
--
-- One row per patient × bite incident × dosage date.
-- Includes next_dosage_date and days_to_next_dose for interval analysis.
-- Reuses the same bite incident logic from z24_bite_episode_analysis.
-- =============================================================================

WITH raw_data AS (
    SELECT *
    FROM {{ ref('z24_acn_datacut_2425') }}
),

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
-- Classify claims (same rules as z24_bite_episode_analysis)
-- =====================================================================

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
-- Bite incident detection (90-day gap rule)
-- =====================================================================

bite_with_gaps AS (
    SELECT 
        maskedcardno,
        service_date,
        {% if target.type == 'bigquery' %}
            DATE_DIFF(
                service_date,
                LAG(service_date) OVER (
                    PARTITION BY maskedcardno ORDER BY service_date
                ),
                DAY
            ) AS days_since_prev_bite
        {% else %}
            service_date - LAG(service_date) OVER (
                PARTITION BY maskedcardno ORDER BY service_date
            ) AS days_since_prev_bite
        {% endif %}
    FROM bite_claims
),

bite_incidents AS (
    SELECT 
        maskedcardno,
        service_date,
        SUM(
            CASE 
                WHEN days_since_prev_bite IS NULL 
                  OR days_since_prev_bite > 90 
                THEN 1 ELSE 0 
            END
        ) OVER (
            PARTITION BY maskedcardno ORDER BY service_date
        ) AS bite_incident_number
    FROM bite_with_gaps
),

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

-- =====================================================================
-- Map each dosage to its bite incident
-- =====================================================================

dosages_mapped AS (
    SELECT 
        d.maskedcardno,
        b.bite_incident_number,
        b.bite_date,
        b.next_bite_date,
        d.service_date AS dosage_date,
        d.approved
    FROM bite_episode_starts b
    INNER JOIN dosage_claims d
        ON d.maskedcardno = b.maskedcardno
        AND d.service_date >= b.bite_date
        AND (b.next_bite_date IS NULL OR d.service_date < b.next_bite_date)
),

-- =====================================================================
-- Add sequencing: dose number, next dosage date, days between doses
-- =====================================================================

dosage_sequenced AS (
    SELECT 
        maskedcardno,
        bite_incident_number,
        bite_date,
        next_bite_date,
        dosage_date,
        approved,
        ROW_NUMBER() OVER (
            PARTITION BY maskedcardno, bite_incident_number 
            ORDER BY dosage_date
        ) AS dose_number,
        LEAD(dosage_date) OVER (
            PARTITION BY maskedcardno, bite_incident_number 
            ORDER BY dosage_date
        ) AS next_dosage_date
    FROM dosages_mapped
)

-- =====================================================================
-- FINAL OUTPUT: One row per dosage claim
-- =====================================================================
SELECT 
    s.maskedcardno,
    dm.gender,
    dm.age,
    dm.membershiptype,
    dm.corpcode,
    dm.branchdesc,
    s.bite_incident_number,
    s.bite_date,
    s.next_bite_date,
    s.dose_number,
    s.dosage_date,
    s.next_dosage_date,
    s.approved,
    {% if target.type == 'bigquery' %}
        DATE_DIFF(s.dosage_date, s.bite_date, DAY) AS days_since_bite,
        DATE_DIFF(s.next_dosage_date, s.dosage_date, DAY) AS days_to_next_dose
    {% else %}
        (s.dosage_date - s.bite_date) AS days_since_bite,
        (s.next_dosage_date - s.dosage_date) AS days_to_next_dose
    {% endif %}
FROM dosage_sequenced s
LEFT JOIN patient_demographics dm
    ON s.maskedcardno = dm.maskedcardno
ORDER BY s.maskedcardno, s.bite_incident_number, s.dose_number
