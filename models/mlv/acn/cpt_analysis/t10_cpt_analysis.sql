{{ config(materialized='table') }}

{{ standardized_cpt_member_analysis([
    'Lipid Profile',
    'Ultrasound - Whole Abdomen',
    '2D Echo with Doppler',
    'HbA1c',
    'Thyroid Panel',
    'Creatinine',
    'Thyroid Stimulating Hormone (TSH)',
    'Dengue Test',
    'SGPT/ALT',
    'Ultrasound - Transvaginal'
], 'selected_cpt') }}
