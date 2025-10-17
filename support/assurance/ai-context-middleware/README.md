---
sqlpage-conf:
  database_url: "sqlite://scf-2025.3.sqlite.db?mode=rwc"
  web_root: "./"
  allow_exec: true
  port: 9227
---
## Secure Controls Framework (SCF) Exploration

This script automates the conversion of the latest Secure Controls Framework
(SCF) Excel workbook from the
[official SCF GitHub repository](https://github.com/securecontrolsframework/securecontrolsframework)
into a structured SQLite database.

- Uses DuckDB with its built-in `excel` and `sqlite` extensions.
- Reads each major worksheet from the SCF Excel workbook (e.g., _SCF 2025.3_,
  _Authoritative Sources_, _Assessment Objectives_, etc.).
- Creates corresponding SQLite tables with matching names (e.g., `scf_control`,
  `scf_authoritative_source`, etc.).
- All columns are imported as untyped strings (`VARCHAR`), preserving the
  original Excel text exactly as-is.
- Adds a metadata column `scf_xls_source` to every table to record the source
  workbook name for provenance.
- Creates a registry view `scf_xls_sheet` listing each imported sheet, its
  corresponding table, and the source file name.

Instructions:

1. Download the SCF Excel workbook from the GitHub repo.
2. Run the DuckDB SQL script.

   ```bash
   rm -f scf-2025.3.sqlite.db && cat prepare.duckdb.sql | duckdb ":memory:"
   ```

## Layout

```sql LAYOUT
-- BEGIN: global LAYOUT (defaults to **/*)
SELECT 'shell' AS component,
       'AI Context Middleware' AS title,
       NULL AS icon,
       'https://www.surveilr.com/assets/brand/content-assembler.ico' AS favicon,
       'https://www.surveilr.com/assets/brand/compliance-explorer.png' AS image,
       'fluid' AS layout,
       true AS fixed_top_menu,
       'index.sql' AS link,
       '{"link":"/index.sql","title":"Home"}' AS menu_item;

SET resource_json = sqlpage.read_file_as_text('spry.d/auto/resource/${path}.auto.json');
SET page_title = json_extract($resource_json, '$.route.caption');
-- END: global LAYOUT (defaults to **/*)
```

```sql index.sql { route: { caption: "Home" } }
SELECT 'card' AS component,
       '' AS title,
       2 AS columns;

-- Dynamic navigation discovery (following SCF pattern)
SELECT json_extract(np.json, '$.caption') AS title,
       json_extract(np.json, '$.caption') AS description_md,
       ${ctx.absUrlUnquoted("nn.path")} AS link
FROM navigation_node AS nn
INNER JOIN navigation_payload AS np
  ON nn.path = np.path
WHERE nn.is_index <> 1 
  AND nn.virtual <> 1 
  AND nn.parent_path = '/ai-context';
```

# AI Context Engineering Pages

```sql ai-context-engineering/compliance.sql { route: { caption: "Compliance Overview" } }
SELECT 'text' AS component,
       $page_title AS title;

SELECT 'card' AS component,
       3 AS columns;

-- -- HIPAA compliance card
-- SELECT '## Total Counts of HIPAA Prompt Modules' AS description_md,
--        'white' AS background_color,
--        '## ' || count(DISTINCT uniform_resource_id) AS description_md,
--        '12' AS width,
--        'pink' AS color,
--        'timeline-event' AS icon,
--        'background-color: #FFFFFF' AS style,
--        ${ctx.absUrlUnquoted("'/ai-context-engineering/prompts-complaince-hipaa.sql'")} AS link
-- FROM ai_ctxe_view_uniform_resource_complaince 
-- WHERE regime = 'HIPAA';

-- -- SOC2 compliance card
-- SELECT '## Total Counts of SOC2 Prompt Modules' AS description_md,
--        'white' AS background_color,
--        '## ' || count(DISTINCT uniform_resource_id) AS description_md,
--        '12' AS width,
--        'blue' AS color,
--        'timeline-event' AS icon,
--        'background-color: #FFFFFF' AS style,
--        ${ctx.absUrlUnquoted("'/ai-context-engineering/prompts-complaince-soc.sql'")} AS link
-- FROM ai_ctxe_view_uniform_resource_complaince 
-- WHERE regime = 'SOC2';
-- ```

```sql ai-context-engineering/index.sql { route: { caption: "AI Context Engineering" } }
SELECT 'text' AS component,
       $page_title AS title;

SELECT 'card' AS component,
       '' AS title,
       2 AS columns;

-- Dynamic navigation discovery
SELECT json_extract(np.json, '$.caption') AS title,
       json_extract(np.json, '$.caption') AS description_md,
       ${ctx.absUrlUnquoted("nn.path")} AS link
FROM navigation_node AS nn
INNER JOIN navigation_payload AS np
  ON nn.path = np.path
WHERE nn.is_index <> 1 
  AND nn.virtual <> 1 
  AND nn.parent_path = '/ai-context-engineering';
```

```sql ai-context-engineering/prompts-complaince-hipaa.sql { route: { caption: "HIPAA Compliance Prompts" } }
SELECT 'text' AS component,
       $page_title AS title;

${paginate("ai_ctxe_view_uniform_resource_complaince", "WHERE regime='HIPAA'")}

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS search;

SELECT uniform_resource_id AS "Resource ID",
       regime AS "Regime",
       created_at AS "Created"
FROM ai_ctxe_view_uniform_resource_complaince 
WHERE regime = 'HIPAA'
ORDER BY created_at DESC
${pagination.limit};

${pagination.navigation}
```

```sql ai-context-engineering/prompts-complaince-soc.sql { route: { caption: "SOC2 Compliance Prompts" } }
SELECT 'text' AS component,
       $page_title AS title;

${paginate("ai_ctxe_view_uniform_resource_complaince", "WHERE regime='SOC2'")}

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS search;

SELECT uniform_resource_id AS "Resource ID",
       regime AS "Regime",
       created_at AS "Created"
FROM ai_ctxe_view_uniform_resource_complaince 
WHERE regime = 'SOC2'
ORDER BY created_at DESC
${pagination.limit};

${pagination.navigation}
```

```sql ai-context/opsfolio.sql { route: { caption: "OpsFolio Prompts" } }
SELECT 'text' AS component,
       $page_title AS title;

${paginate("ai_ctxe_uniform_resource_prompts")}

SELECT 'table' AS component,
       TRUE AS sort,
       TRUE AS search;

SELECT '## ' || count(*) AS description_md,
       'blue' AS color,
       'database' AS icon
FROM ai_ctxe_uniform_resource_prompts
${pagination.limit};

${pagination.navigation}
```

## Regime Explorer Page

```sql ai-context/scf-explorer.sql { route: { caption: "SCF Control Regimes" } }
SELECT 'text' AS component,
       $page_title AS title;

${paginate("scf_regime_count")}

SELECT 'table' AS component,
       TRUE     AS sort,
       'Regime' as  markdown,
       TRUE     AS search;              
SELECT
      '[' || regime || '](' || ${ctx.absUrlUnquoted("'' || 'details/regime.sql?regime=' || replace(replace(replace(regime, ' ', '%20'), '&', '%26'), '#', '%23') || ''")} || ')' AS "Regime", 
      control_count AS "Controls"
FROM scf_regime_count
ORDER BY control_count DESC, regime
${pagination.limit};

${pagination.navigation}
```

## Controls per regime (totals) details page
 
```sql ai-context/details/regime.sql { route: { caption: "Controls per regime (totals) details" } }
SELECT 'text' AS component,
       $page_title || ' for ' || $regime AS title;
 
${paginate("scf_regime_control", "WHERE regime_label = $regime")}

 
SELECT 'table' AS component,
       TRUE AS sort,
       'SCF #' AS markdown,
       TRUE AS search; 
                 
SELECT '[' || regime_raw_value || '](scf-prompt-details.sql?regime_raw_value=' || 
       regime_raw_value|| ')' AS "SCF #",
       scf_control AS  "Regime Marker",
       scf_control_question AS "SCF Control Question"
FROM scf_regime_control
WHERE regime_label = $regime
ORDER BY scf_no
${pagination.limit};
 
${pagination.navWithParams("regime")}
```
 
## SCF Control Prompt Details page
 
```sql ai-context/details/scf-prompt-details.sql { route: { caption: "SCF Prompt Details" } }
SELECT 'text' AS component,
       $page_title || ' for SCF # ' || $scf_no AS title;
 
${paginate("scf_regime_control", "WHERE scf_no = $scf_no")}

      -- First card for accordion (frontmatter details)
      SELECT 'html' AS component,
      '<details open>
      <summary>Frontmatter details</summary>
      <div>' AS html;
     
      SELECT 'card' AS component, 1 as columns;
     
      SELECT
     a.title AS "Title",
     a.frontmatter_control_question AS description_md,
     a.frontmatter_control_id AS description_md,
     a.frontmatter_control_id AS description_md,
     a.fiiId AS description_md,
     a.frontmatter_summary AS description_md

      FROM ai_ctxe_view_uniform_resource_compliance a
      where frontmatter_control_id=$regime_raw_value
     
      SELECT 'html' AS component, '</div></details>' AS html;
 
SELECT
  'card' AS component,
  '' AS title,
  1 AS columns;
SELECT  
body_text AS description_md
      FROM ai_ctxe_view_uniform_resource_compliance  where frontmatter_control_id=$regime_raw_value
```
