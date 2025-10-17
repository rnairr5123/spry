-- ============================================================================
-- SCF (Secure Controls Framework) Analysis Views
-- Created: 2025-10-15
-- Purpose: Provides analytical views for SCF compliance data
-- ============================================================================

-- Drop existing views if they exist
DROP VIEW IF EXISTS aictxe_regime_control_standardized;

-- ============================================================================
-- View 1: Standardized SCF Control Numbers
-- Transforms SCF control numbers to FII standard format
-- Example: CFG-01.2 -> FII-SCF-CFG-0001.2
-- ============================================================================
CREATE VIEW aictxe_regime_control_standardized AS
SELECT 
    *,
    'FII-SCF-' || 
    SUBSTR(scf_no, 1, 3) || 
    '-' ||
    PRINTF('%04d', 
        CAST(
            CASE 
                WHEN INSTR(SUBSTR(scf_no, 5), '.') > 0 
                THEN SUBSTR(SUBSTR(scf_no, 5), 1, INSTR(SUBSTR(scf_no, 5), '.') - 1)
                ELSE SUBSTR(scf_no, 5)
            END AS INTEGER
        )
    ) ||
    CASE 
        WHEN INSTR(SUBSTR(scf_no, 5), '.') > 0 
        THEN '.' || SUBSTR(SUBSTR(scf_no, 5), INSTR(SUBSTR(scf_no, 5), '.') + 1)
        ELSE ''
    END AS fii_id
FROM scf_regime_control_unpivoted;


-- database: ./resource-surveillance.sqlite.db

-- ============================================================================
-- SCF (Secure Controls Framework) Analysis Views
-- Created: 2025-10-15
-- Purpose: Provides analytical views for SCF compliance data
-- ============================================================================

-- Drop existing views if they exist
DROP VIEW IF EXISTS aictxe_regime_control_standardized;

-- ============================================================================
-- View 1: Standardized SCF Control Numbers
-- Transforms SCF control numbers to FII standard format
-- Example: CFG-01.2 -> FII-SCF-CFG-0001.2
-- ============================================================================
CREATE VIEW aictxe_regime_control_standardized AS
SELECT 
    *,
    'FII-SCF-' || 
    SUBSTR(scf_no, 1, 3) || 
    '-' ||
    PRINTF('%04d', 
        CAST(
            CASE 
                WHEN INSTR(SUBSTR(scf_no, 5), '.') > 0 
                THEN SUBSTR(SUBSTR(scf_no, 5), 1, INSTR(SUBSTR(scf_no, 5), '.') - 1)
                ELSE SUBSTR(scf_no, 5)
            END AS INTEGER
        )
    ) ||
    CASE 
        WHEN INSTR(SUBSTR(scf_no, 5), '.') > 0 
        THEN '.' || SUBSTR(SUBSTR(scf_no, 5), INSTR(SUBSTR(scf_no, 5), '.') + 1)
        ELSE ''
    END AS fii_id
FROM scf_regime_control_unpivoted;


-- Create a foundation view with common patterns - MUST BE FIRST
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_base;
CREATE VIEW ai_ctxe_uniform_resource_base AS
SELECT 
    ur.uniform_resource_id,
    ur.uri,
    ur.created_at,
    ur.created_by,
    ur.content,
    ur.frontmatter,
    ur.nature,
    
    -- Centralized filename extraction
    CASE 
        WHEN urf.file_path_rel LIKE '%/%' THEN 
            substr(urf.file_path_rel, length(rtrim(urf.file_path_rel, replace(urf.file_path_rel, '/', ''))) + 1)
        ELSE 
            urf.file_path_rel
    END AS filename,
    
    -- Centralized frontmatter stripping
    TRIM(
        CASE
            WHEN instr(ur.content, '---') = 1 THEN substr(
                ur.content,
                instr(ur.content, '---') + 3 + instr(substr(ur.content, instr(ur.content, '---') + 3), '---') + 3
            )
            ELSE ur.content
        END
    ) AS body_text,
    
    -- Common JSON extractions
    json_extract(ur.frontmatter, '$.title') AS title,
    json_extract(ur.frontmatter, '$.summary') AS summary,
    json_extract(ur.frontmatter, '$.merge-group') AS merge_group,
    COALESCE(json_extract(ur.frontmatter, '$.order'), 999999) AS ord,
    
    -- File metadata
    urf.nature AS file_nature,
    urf.source_path,
    urf.file_path_rel,
    urf.size_bytes

FROM uniform_resource ur
LEFT JOIN uniform_resource_file urf ON ur.uniform_resource_id = urf.uniform_resource_id
WHERE ur.deleted_at IS NULL;

-- Drop and create view for uniform_resource summary
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_summary;
CREATE VIEW ai_ctxe_uniform_resource_summary AS
SELECT
  COUNT(*) AS total_files_seen, -- Total files seen
  COUNT(*) FILTER (WHERE content IS NOT NULL AND LENGTH(TRIM(content)) > 0) AS files_with_content, -- Files with content
  COUNT(*) FILTER (WHERE frontmatter IS NOT NULL AND LENGTH(TRIM(frontmatter)) > 0) AS files_with_frontmatter, -- Files with frontmatter
  MIN(last_modified_at) AS oldest_modified_at, -- Oldest modified date
  MAX(last_modified_at) AS youngest_modified_at -- Youngest modified date
FROM uniform_resource
WHERE uri IS NOT NULL;


-- Drop and create view for uniform_resource prompts
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_prompts;
CREATE VIEW ai_ctxe_uniform_resource_prompts AS
SELECT 
    base.uniform_resource_id,
    base.uri,
    base.filename,
    base.created_at,
    base.created_by,
    base.content,
    base.frontmatter,
    base.title,
    base.summary,
    base.merge_group,
    base.ord,
    base.body_text,
    base.file_nature AS nature,
    base.source_path,
    base.file_path_rel,
    base.size_bytes
FROM ai_ctxe_uniform_resource_base base
INNER JOIN ur_ingest_session_fs_path_entry fs 
    ON fs.uniform_resource_id = base.uniform_resource_id
WHERE (fs.file_basename LIKE '%.prompt.md' 
    OR fs.file_basename LIKE '%.prompt-snippet.md'
    OR fs.file_basename LIKE '%-prompt-meta.md');


-- Drop and create view for uniform_resource frontmatter
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_frontmatter_view;
CREATE VIEW ai_ctxe_uniform_resource_frontmatter_view AS

SELECT DISTINCT
    ur.uniform_resource_id,
    ur.uri,
    -- Extracting only important keys from the frontmatter column
    json_extract(ur.frontmatter, '$.id') AS frontmatter_id,
   COALESCE(
    json_extract(ur.frontmatter, '$.title'),
    ur.title
) AS title,
    json_extract(ur.frontmatter, '$.summary') AS frontmatter_summary,
  json_extract(ur.frontmatter, '$.merge-group') AS frontmatter_merge_group,
    json_extract(ur.frontmatter, '$.artifact-nature') AS frontmatter_artifact_nature,
   
    json_extract(ur.frontmatter, '$.lifecycle') AS frontmatter_lifecycle,
    json_extract(ur.frontmatter, '$.visibility') AS frontmatter_visibility,
    json_extract(ur.frontmatter, '$.audience') AS frontmatter_audience,
    json_extract(ur.frontmatter, '$.function') AS frontmatter_function,
    json_extract(ur.frontmatter, '$.product.name') AS frontmatter_product_name,
    
    -- Extracting features dynamically (up to the first 5 features)
    trim(
        json_extract(ur.frontmatter, '$.product.features[0]') || ',' ||
        json_extract(ur.frontmatter, '$.product.features[1]') || ',' ||
        json_extract(ur.frontmatter, '$.product.features[2]') || ',' ||
        json_extract(ur.frontmatter, '$.product.features[3]') || ',' ||
        json_extract(ur.frontmatter, '$.product.features[4]')
    ) AS frontmatter_product_features,
    
    json_extract(ur.frontmatter, '$.provenance.source-uri') AS frontmatter_provenance_source_uri,
    json_extract(ur.frontmatter, '$.provenance.dependencies') AS frontmatter_provenance_dependencies,

    -- Extracting reviewers dynamically (up to the first 5 reviewers)
    trim(
        json_extract(ur.frontmatter, '$.provenance.reviewers[0]') || ',' ||
        json_extract(ur.frontmatter, '$.provenance.reviewers[1]')
    ) AS frontmatter_reviewers,
      json_extract(urt.elaboration, '$.validation.status') AS validation_status,
      json_extract(urt.elaboration, '$.warnings[0]') AS elaboration_warning

FROM ai_ctxe_uniform_resource_prompts ur
LEFT JOIN uniform_resource_transform urt
  ON ur.uniform_resource_id = urt.uniform_resource_id;
    

-- Drop and create view for files with content
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_with_content;

CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_with_content AS
SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    base.filename,
    base.created_at,
    base.created_by,
    base.content,
    base.frontmatter,
    base.title,
    base.summary,
    base.body_text,
    base.file_nature AS nature,
    base.source_path,
    base.file_path_rel,
    base.size_bytes
FROM ai_ctxe_uniform_resource_base base
WHERE base.content IS NOT NULL AND LENGTH(TRIM(base.content)) > 0;

-- Drop and create view for files with frontmatter
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_with_frontmatter;

CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_with_frontmatter AS
SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    base.filename,
    base.created_at,
    base.created_by,
    base.content,
    base.frontmatter,
    base.title,
    base.summary,
    base.body_text,
    base.file_nature AS nature,
    base.source_path,
    base.file_path_rel,
    base.size_bytes
FROM ai_ctxe_uniform_resource_base base
WHERE base.frontmatter IS NOT NULL AND LENGTH(TRIM(base.frontmatter)) > 0;

-- Drop and create view for all files
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_all_files;

CREATE VIEW ai_ctxe_uniform_resource_all_files AS
SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    COALESCE(fs.file_basename, base.filename) AS filename,
    base.nature,
    base.created_at,
    base.created_by,
    base.content,
    base.frontmatter,
    base.title,
    base.summary,
    base.body_text
FROM ai_ctxe_uniform_resource_base base
LEFT JOIN ur_ingest_session_fs_path_entry fs
  ON fs.uniform_resource_id = base.uniform_resource_id;

-- Drop and create view for risk panel
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_risk_view;
CREATE VIEW ai_ctxe_uniform_resource_risk_view AS
SELECT
    -- Count of resources with null or empty frontmatter
    (
        SELECT COUNT(*)
        FROM uniform_resource
        WHERE deleted_at IS NULL
          AND (frontmatter IS NULL OR LENGTH(TRIM(frontmatter)) = 0)
    ) AS count_empty_frontmatter,

    -- Count of grouped resources where order is null or count > 1
    (
        SELECT COUNT(*)
        FROM (
            SELECT 
                json_extract(frontmatter, '$.merge-group') AS mg,
                json_extract(frontmatter, '$.order') AS ord,
                COUNT(*) AS ct
            FROM uniform_resource
            WHERE deleted_at IS NULL
              AND frontmatter IS NOT NULL
              AND json_extract(frontmatter, '$.merge-group') IS NOT NULL
            GROUP BY mg, ord
            HAVING ord IS NULL OR ct > 1
        ) AS grouped_resources
    ) AS count_grouped_resources,

    -- Count of files over 1MB linked to non-deleted resources
    (
        SELECT COUNT(*)
        FROM uniform_resource_file urf
        JOIN uniform_resource ur ON urf.uniform_resource_id = ur.uniform_resource_id
        WHERE ur.deleted_at IS NULL
          AND urf.size_bytes > 1048576
    ) AS count_large_files;


-- Drop and create view for files without frontmatter
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_without_frontmatter;

CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_without_frontmatter AS

SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    base.created_at,
    base.content,
    base.nature,
    base.filename
FROM ai_ctxe_uniform_resource_base base
WHERE base.frontmatter IS NULL OR LENGTH(TRIM(base.frontmatter)) = 0;


-- Drop and create view for oversized files
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_oversized_list;

CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_oversized_list AS

SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    base.created_at,
    base.content,
    base.nature,
    base.filename,
    base.size_bytes
FROM ai_ctxe_uniform_resource_base base
WHERE base.size_bytes > 1048576;


-- Drop and create view for merge group risks
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_merge_group_risks;

CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_merge_group_risks AS
SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    base.created_at,
    base.body_text,
    base.nature,
    base.merge_group,
    base.ord AS merge_order,
    COALESCE(fs.file_basename, base.filename) AS filename
FROM ai_ctxe_uniform_resource_base base
LEFT JOIN ur_ingest_session_fs_path_entry fs
  ON fs.uniform_resource_id = base.uniform_resource_id
WHERE (
    base.merge_group IS NULL
    OR (
        base.merge_group IS NOT NULL
        AND base.ord = 999999  -- This represents NULL order since we COALESCE to 999999
    )
);


--- === frontmatter validation ===
---DROP VIEW IF EXISTS opsfolio_frontmatter_validation;
---CREATE VIEW IF NOT EXISTS opsfolio_invalid_frontmatter AS
-- SELECT 
--     ur.uniform_resource_id,
--     ur.uri,
--     ur.created_at,
--     ur.content,
--     ur.nature,
--     ur.frontmatter,
--     fs.file_basename as filename
-- FROM 
--     uniform_resource ur
-- JOIN
--     ur_ingest_session_fs_path_entry fs ON fs.uniform_resource_id = ur.uniform_resource_id
-- WHERE
--     ur.deleted_at IS NULL
--     AND ur.frontmatter IS NOT NULL
--     AND json_schema_valid(
--         '{
--             "type": "object",
--             "properties": {
--                 "id": { "type": "string" },
--                 "title": { "type": "string" },
--                 "summary": { "type": "string" },
--                 "artifact-nature": { "type": "string" },
--                 "function": { "type": "string" },
--                 "audience": { "type": "string" },
--                 "visibility": { "type": "string" },
--                 "tenancy": { "type": "string" },
--                 "product": {
--                     "type": "object",
--                     "properties": {
--                         "name": { "type": "string" },
--                         "version": { "type": "string" },
--                         "features": {
--                             "type": "array",
--                             "items": { "type": "string" }
--                         }
--                     },
--                     "required": ["name", "version", "features"]
--                 },
--                 "provenance": {
--                     "type": "object",
--                     "properties": {
--                         "source-uri": { "type": "string" },
--                         "reviewers": {
--                             "type": "array",
--                             "items": { "type": "string" }
--                         },
--                         "dependencies": {
--                             "type": "array",
--                             "items": { "type": "string" }
--                         }
--                     },
--                     "required": ["source-uri", "reviewers", "dependencies"]
--                 },
--                 "merge-group": { "type": "string" },
--                 "order": { "type": "number" }
--             },
--             "required": [
--                 "id", "title", "summary", "artifact-nature", "function", "audience", 
--                 "visibility", "tenancy", "product", "provenance", "merge-group", "order"
--             ]
--         }', 
--         ur.frontmatter
--     ) = 0;-- 

-- Drop and create view for anythingllm
DROP VIEW IF EXISTS uniform_resource_build_anythingllm;
CREATE VIEW uniform_resource_build_anythingllm AS
SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,
    base.filename,
    base.created_at,
    base.created_by,
    base.content,
    base.frontmatter,
    base.title,
    base.summary,
    base.body_text,
    base.file_nature AS nature,
    base.source_path,
    base.file_path_rel,
    base.size_bytes
FROM ai_ctxe_uniform_resource_base base
WHERE base.uri LIKE '%.build/anythingllm%';

-- Drop and create view for anythingllm frontmatter
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_frontmatter_view_anythingllm;
CREATE VIEW ai_ctxe_uniform_resource_frontmatter_view_anythingllm AS

SELECT DISTINCT
    uniform_resource_id,
    uri,
    -- Extracting only important keys from the frontmatter column
    json_extract(frontmatter, '$.id') AS frontmatter_id,
    json_extract(frontmatter, '$.title') AS title,
    json_extract(frontmatter, '$.summary') AS frontmatter_summary,
  json_extract(frontmatter, '$.merge-group') AS frontmatter_merge_group,
    json_extract(frontmatter, '$.artifact-nature') AS frontmatter_artifact_nature,
   
    json_extract(frontmatter, '$.lifecycle') AS frontmatter_lifecycle,
    json_extract(frontmatter, '$.visibility') AS frontmatter_visibility,
    json_extract(frontmatter, '$.audience') AS frontmatter_audience,
    json_extract(frontmatter, '$.function') AS frontmatter_function,
    json_extract(frontmatter, '$.product.name') AS frontmatter_product_name,
    
    -- Extracting features dynamically (up to the first 5 features)
    trim(
        json_extract(frontmatter, '$.product.features[0]') || ',' ||
        json_extract(frontmatter, '$.product.features[1]') || ',' ||
        json_extract(frontmatter, '$.product.features[2]') || ',' ||
        json_extract(frontmatter, '$.product.features[3]') || ',' ||
        json_extract(frontmatter, '$.product.features[4]')
    ) AS frontmatter_product_features,
    
    json_extract(frontmatter, '$.provenance.source-uri') AS frontmatter_provenance_source_uri,
    json_extract(frontmatter, '$.provenance.dependencies') AS frontmatter_provenance_dependencies,

    -- Extracting reviewers dynamically (up to the first 5 reviewers)
    trim(
        json_extract(frontmatter, '$.provenance.reviewers[0]') || ',' ||
        json_extract(frontmatter, '$.provenance.reviewers[1]')
    ) AS frontmatter_reviewers
    
FROM uniform_resource_build_anythingllm;

-- Drop and create view for transformed resources cleaned
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_transformed_resources_cleaned;
CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_transformed_resources_cleaned AS
SELECT DISTINCT
    ur.uniform_resource_id,
    ur.uri,
    ur.nature,
     fs.file_basename as filename,
    -- Remove frontmatter from content
    TRIM(
        CASE
            WHEN instr(urt.content, '---') = 1 THEN substr(
                urt.content,
                instr(urt.content, '---') + 3 + instr(substr(urt.content, instr(urt.content, '---') + 3), '---') + 3
            )
            ELSE urt.content
        END
    ) AS body_content,
    json_extract(urt.elaboration, '$.validation.status') AS validation_status,
    json_extract(urt.elaboration, '$.warnings') AS warnings
FROM uniform_resource ur
LEFT JOIN uniform_resource_transform urt
  ON ur.uniform_resource_id = urt.uniform_resource_id
  LEFT JOIN
  ur_ingest_session_fs_path_entry fs
  ON fs.uniform_resource_id = ur.uniform_resource_id AND fs.uniform_resource_id=urt.uniform_resource_id
WHERE ur.deleted_at IS NULL
  AND (
      json_extract(urt.elaboration, '$.validation.status') IS NULL
      OR json_extract(urt.elaboration, '$.validation.status') != 'success'
  );

-- Drop and create view for transformed resources valid
DROP VIEW IF EXISTS ai_ctxe_uniform_resource_transformed_resources_valid;
CREATE VIEW IF NOT EXISTS ai_ctxe_uniform_resource_transformed_resources_valid AS
SELECT DISTINCT
    ur.uniform_resource_id,
    ur.uri,
    ur.nature,
    ur.created_at,
     fs.file_basename as filename,
    -- Remove frontmatter from content
    TRIM(
        CASE
            WHEN instr(urt.content, '---') = 1 THEN substr(
                urt.content,
                instr(urt.content, '---') + 3 + instr(substr(urt.content, instr(urt.content, '---') + 3), '---') + 3
            )
            ELSE urt.content
        END
    ) AS body_content,
    json_extract(urt.elaboration, '$.validation.status') AS validation_status,
    json_extract(urt.elaboration, '$.warnings') AS warnings
FROM uniform_resource ur
JOIN uniform_resource_transform urt
  ON ur.uniform_resource_id = urt.uniform_resource_id
  JOIN
  ur_ingest_session_fs_path_entry fs
  ON fs.uniform_resource_id = ur.uniform_resource_id AND fs.uniform_resource_id=urt.uniform_resource_id
WHERE ur.deleted_at IS NULL
  AND (
      json_extract(urt.elaboration, '$.validation.status') = 'success'
  );


DROP VIEW IF EXISTS ai_ctxe_view_uniform_resource_compliance;
CREATE VIEW ai_ctxe_view_uniform_resource_compliance AS
SELECT DISTINCT
    base.uniform_resource_id,
    base.uri,

    -- Extract regime from URI


    base.filename,
    base.created_at,
    base.created_by,
    base.content,
    base.frontmatter,
    base.merge_group,
    base.ord,
    base.body_text,
    base.file_nature AS nature,
    base.source_path,
    base.file_path_rel,
    base.size_bytes,
    
    -- Additional compliance-specific frontmatter extractions
    json_extract(base.frontmatter, '$.title') AS title,
    json_extract(base.frontmatter, '$.description') AS frontmatter_summary,
    json_extract(base.frontmatter, '$.control-question') AS frontmatter_control_question,
    json_extract(base.frontmatter, '$.control-id') AS frontmatter_control_id,
    json_extract(base.frontmatter, '$.fiiId') AS fiiId,
    json_extract(base.frontmatter, '$.regimeType') AS regimeType,
    json_extract(base.frontmatter, '$.documentType') AS document_type


FROM ai_ctxe_uniform_resource_base base
INNER JOIN ur_ingest_session_fs_path_entry fs
    ON fs.uniform_resource_id = base.uniform_resource_id
WHERE (
    json_extract(base.frontmatter, '$.promptType')='SCF'
  )
  AND (fs.file_basename LIKE '%.prompt.md' 
    OR fs.file_basename LIKE '%.prompt-snippet.md' 
    OR fs.file_basename LIKE '%-prompt-meta.md');



-- ============================================================================
-- AI Context Middleware Analytics Catalog
-- Self-documenting registry of all available views and their purposes
-- ============================================================================
DROP VIEW IF EXISTS ai_ctxe_analytics_view;
CREATE VIEW ai_ctxe_analytics_view AS
WITH entries(view_schema, view_name, title, description) AS (
  VALUES
    ('main','aictxe_regime_control_standardized','SCF Control ID Standardization',
     'Transforms SCF control numbers to FII standard format (e.g., CFG-01.2 -> FII-SCF-CFG-0001.2). Use for standardized control referencing across systems.'),
    
    ('main','ai_ctxe_uniform_resource_base','Foundation Resource View',
     'Core foundation view providing centralized access to all uniform resources with standardized filename extraction, frontmatter parsing, and JSON field access. All other views build on this foundation.'),
     
    ('main','ai_ctxe_uniform_resource_summary','Resource Summary Statistics',
     'High-level metrics and counts for the entire resource collection including total files, content presence, frontmatter usage, and modification timestamps. Use for dashboard summaries.'),
     
    ('main','ai_ctxe_uniform_resource_prompts','AI Prompt Files',
     'Filtered view of prompt-related files (.prompt.md, .prompt-snippet.md, -prompt-meta.md) with full metadata. Primary dataset for AI context management and prompt engineering workflows.'),
     
    ('main','ai_ctxe_uniform_resource_frontmatter_view','Frontmatter Analysis',
     'Detailed extraction and parsing of frontmatter fields from prompt files including product features, provenance, reviewers, and validation status. Use for metadata quality analysis.'),
     
    ('main','ai_ctxe_uniform_resource_with_content','Files with Content',
     'All resources that contain actual content (non-empty). Use for content analysis, indexing, and processing workflows that require substantive text.'),
     
    ('main','ai_ctxe_uniform_resource_with_frontmatter','Files with Frontmatter',
     'Resources containing structured frontmatter metadata. Essential for metadata-driven operations, categorization, and compliance tracking.'),
     
    ('main','ai_ctxe_uniform_resource_without_frontmatter','Files Missing Frontmatter',
     'Resources lacking structured metadata - potential data quality issues. Use for identifying files that need metadata enhancement or standardization.'),
     
    ('main','ai_ctxe_uniform_resource_all_files','Complete File Inventory',
     'Comprehensive view of all files in the system with unified filename handling. Use for complete system inventory and file management operations.'),
     
    ('main','ai_ctxe_uniform_resource_risk_view','Data Quality Risk Dashboard',
     'Risk assessment metrics including empty frontmatter count, duplicate merge groups, and oversized files. Critical for data governance and quality monitoring.'),
     
    ('main','ai_ctxe_uniform_resource_oversized_list','Large File Detection',
     'Files exceeding size thresholds (>1MB) that may impact system performance or require special handling. Use for storage optimization and performance tuning.'),
     
    ('main','ai_ctxe_uniform_resource_merge_group_risks','Merge Group Issues',
     'Files with missing merge groups or invalid ordering that could cause content assembly problems. Essential for content publishing workflow validation.'),
     
    ('main','uniform_resource_build_anythingllm','AnythingLLM Processing',
     'Resources processed through AnythingLLM pipeline (identified by .build/anythingllm path). Use for tracking AI processing workflows and LLM integration status.'),
     
    ('main','ai_ctxe_uniform_resource_frontmatter_view_anythingllm','AnythingLLM Metadata',
     'Frontmatter analysis specifically for AnythingLLM processed files. Specialized view for AI processing pipeline metadata and quality control.'),
     
    ('main','ai_ctxe_uniform_resource_transformed_resources_cleaned','Failed Transformations',
     'Resources with failed or missing transformation validation. Critical for identifying content processing issues and data pipeline failures.'),
     
    ('main','ai_ctxe_uniform_resource_transformed_resources_valid','Successful Transformations',
     'Resources that passed transformation validation successfully. Use for accessing clean, processed content ready for production use.'),
     
    ('main','ai_ctxe_view_uniform_resource_compliance','Compliance Regime Analysis',
     'Compliance-focused view extracting HIPAA, SOC2, and NIST regime information with control mappings and categorization. Essential for regulatory compliance reporting and audit trails.')
)
SELECT * FROM entries;

-- ============================================================================
-- audit prompt data
-- ============================================================================
DROP VIEW IF EXISTS ai_ctxe_audit_prompt;
CREATE VIEW ai_ctxe_audit_prompt AS
SELECT * from ai_ctxe_view_uniform_resource_compliance where document_type='Audit Prompt';
-- ============================================================================
--author prompt
-- ============================================================================
DROP VIEW IF EXISTS ai_ctxe_author_prompt;
CREATE VIEW ai_ctxe_author_prompt AS
SELECT * from ai_ctxe_view_uniform_resource_compliance where document_type='Author Prompt';

-- ============================================================================
--accordion 
-- ============================================================================
DROP VIEW IF EXISTS ui_policy_audit_accordion;

DROP VIEW IF EXISTS ui_policy_audit_accordion_open;

CREATE VIEW ui_policy_audit_accordion_open AS
SELECT 'html' AS component, '
<details class="test-detail-outer-accordion" open>
  <summary class="test-detail-outer-summary">
    Policy Audit Prompt
  </summary>
  <div class="test-detail-outer-content">
' AS html;


DROP VIEW IF EXISTS ui_policy_audit_accordion_close;
CREATE VIEW ui_policy_audit_accordion_close AS
SELECT 'html' AS component, '
  </div>
</details>
<style>
  .test-detail-outer-accordion {
    border: 1px solid #ddd;
    border-radius: 8px;
    margin: 20px 0;
    overflow: hidden;
  }

  .test-detail-outer-summary {
    background-color: #f5f5f5;
    padding: 15px 20px;
    cursor: pointer;
    font-weight: 600;
    color: #333;
    border: none;
    outline: none;
    user-select: none;
    position: relative;
    transition: background-color 0.2s;
  }

  .test-detail-outer-summary::-webkit-details-marker {
    display: none;
  }

  .test-detail-outer-summary::after {
    content: "+";
    position: absolute;
    right: 20px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 18px;
    font-weight: bold;
    color: #666;
  }

  .test-detail-outer-accordion[open] .test-detail-outer-summary::after {
    content: "−";
  }

  .test-detail-outer-summary:hover {
    background-color: #ebebeb;
  }

  .test-detail-outer-content {
    padding: 20px;
    background-color: white;
    border-top: 1px solid #ddd;
  }
</style>
' AS html;

