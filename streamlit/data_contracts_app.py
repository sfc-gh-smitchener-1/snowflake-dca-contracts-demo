# ============================================================================
# DATA CONTRACTS DEMO - Streamlit in Snowflake Application
# ============================================================================
# A comprehensive dashboard for:
#   1. Snowflake Cortex - Natural language queries on semantic models
#   2. Snowflake Horizon - Governance & observability dashboard
#
# Deploy: Upload to Snowflake stage and create Streamlit app
# ============================================================================

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================

st.set_page_config(
    page_title="Data Contracts Demo",
    page_icon="❄️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# SNOWFLAKE STYLING
# ============================================================================

# Snowflake brand colors
SNOWFLAKE_BLUE = "#29B5E8"
SNOWFLAKE_DARK_BLUE = "#1E3A5F"
SNOWFLAKE_LIGHT_BLUE = "#E8F4F8"
HORIZON_PURPLE = "#7C3AED"
HORIZON_GRADIENT = "linear-gradient(135deg, #7C3AED 0%, #29B5E8 100%)"

# Custom CSS for Snowflake branding
st.markdown("""
<style>
    /* Main app styling */
    .stApp {
        background: linear-gradient(180deg, #0E1117 0%, #1A1F2E 100%);
    }
    
    /* Sidebar styling */
    [data-testid="stSidebar"] {
        background: linear-gradient(180deg, #1E3A5F 0%, #0E1117 100%);
    }
    
    [data-testid="stSidebar"] .stRadio label {
        color: white;
        font-weight: 500;
    }
    
    /* Header styling */
    .main-header {
        background: linear-gradient(135deg, #29B5E8 0%, #1E3A5F 100%);
        padding: 1.5rem 2rem;
        border-radius: 12px;
        margin-bottom: 2rem;
        color: white;
    }
    
    .main-header h1 {
        margin: 0;
        font-size: 2rem;
        font-weight: 700;
    }
    
    .main-header p {
        margin: 0.5rem 0 0 0;
        opacity: 0.9;
    }
    
    /* Horizon header */
    .horizon-header {
        background: linear-gradient(135deg, #7C3AED 0%, #29B5E8 100%);
        padding: 1.5rem 2rem;
        border-radius: 12px;
        margin-bottom: 2rem;
        color: white;
    }
    
    /* Metric cards */
    .metric-card {
        background: #1E2530;
        border-radius: 12px;
        padding: 1.5rem;
        border-left: 4px solid #29B5E8;
    }
    
    .metric-card.success { border-left-color: #10B981; }
    .metric-card.warning { border-left-color: #F59E0B; }
    .metric-card.error { border-left-color: #EF4444; }
    
    /* Stoplight indicators */
    .stoplight {
        display: inline-block;
        width: 16px;
        height: 16px;
        border-radius: 50%;
        margin-right: 8px;
    }
    
    .stoplight.green { background: #10B981; box-shadow: 0 0 8px #10B981; }
    .stoplight.yellow { background: #F59E0B; box-shadow: 0 0 8px #F59E0B; }
    .stoplight.red { background: #EF4444; box-shadow: 0 0 8px #EF4444; }
    
    /* Chat styling */
    .chat-message {
        padding: 1rem;
        border-radius: 12px;
        margin-bottom: 1rem;
    }
    
    .chat-message.user {
        background: #29B5E8;
        color: white;
        margin-left: 20%;
    }
    
    .chat-message.assistant {
        background: #1E2530;
        color: white;
        margin-right: 20%;
        border: 1px solid #29B5E8;
    }
    
    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    
    /* Custom scrollbar */
    ::-webkit-scrollbar {
        width: 8px;
        height: 8px;
    }
    
    ::-webkit-scrollbar-track {
        background: #1E2530;
    }
    
    ::-webkit-scrollbar-thumb {
        background: #29B5E8;
        border-radius: 4px;
    }
</style>
""", unsafe_allow_html=True)

# ============================================================================
# SESSION & DATA
# ============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session"""
    return get_active_session()

@st.cache_data(ttl=60)
def get_dashboard_kpis():
    """Fetch dashboard KPIs"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                ACTIVE_CONTRACTS AS TOTAL_CONTRACTS,
                AVG_HEALTH_SCORE AS OVERALL_HEALTH_PCT,
                AVG_QUALITY_SCORE AS QUALITY_SCORE_PCT,
                SLA_COMPLIANCE_24H AS SLA_COMPLIANCE_PCT,
                COALESCE(CRITICAL_ALERTS, 0) + COALESCE(WARNING_ALERTS, 0) AS ACTIVE_ALERTS,
                HEALTHY_COUNT,
                WARNING_COUNT,
                CRITICAL_COUNT
            FROM GOVERNANCE.OBSERVABILITY.VW_DASHBOARD_KPIS
        """).to_pandas()
        return df
    except Exception as e:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_contract_health():
    """Fetch contract health data"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD
            ORDER BY CONSUMER_COUNT DESC
        """).to_pandas()
        return df
    except Exception as e:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_active_alerts():
    """Fetch active alerts"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_ACTIVE_ALERTS
            WHERE STATUS IN ('OPEN', 'ACKNOWLEDGED')
            ORDER BY CREATED_AT DESC
            LIMIT 20
        """).to_pandas()
        return df
    except Exception as e:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_sla_compliance():
    """Fetch SLA compliance trend"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_SLA_COMPLIANCE_TREND
            ORDER BY HOUR DESC
            LIMIT 48
        """).to_pandas()
        return df
    except Exception as e:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_tag_coverage():
    """Fetch tag coverage aggregated by tag type"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                'DATA_CLASSIFICATION' AS TAG_NAME,
                AVG(CLASSIFICATION_COVERAGE_PCT) AS COVERAGE_PCT
            FROM GOVERNANCE.OBSERVABILITY.VW_TAG_COVERAGE
            UNION ALL
            SELECT 
                'PII_TYPE' AS TAG_NAME,
                AVG(PII_COVERAGE_PCT) AS COVERAGE_PCT
            FROM GOVERNANCE.OBSERVABILITY.VW_TAG_COVERAGE
            UNION ALL
            SELECT 
                'AI_ALLOWED' AS TAG_NAME,
                AVG(AI_COVERAGE_PCT) AS COVERAGE_PCT
            FROM GOVERNANCE.OBSERVABILITY.VW_TAG_COVERAGE
        """).to_pandas()
        return df
    except Exception as e:
        return pd.DataFrame()

@st.cache_data(ttl=300)
def get_semantic_models():
    """List available semantic models"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT DISTINCT RELATIVE_PATH as MODEL_NAME
            FROM DIRECTORY('@SEM_DEV.SEM_SALES.SEMANTIC_MODELS')
            WHERE RELATIVE_PATH LIKE '%.yaml'
        """).to_pandas()
        return df['MODEL_NAME'].tolist() if not df.empty else []
    except Exception as e:
        return ['sales_analytics_model.yaml', 'customer_analytics_model.yaml', 
                'product_analytics_model.yaml', 'governance_analytics_model.yaml']

def run_cortex_analyst(question: str, model_path: str) -> tuple:
    """Run Cortex Analyst query - returns (response_text, sql_query, result_df)"""
    session = get_session()
    try:
        # Build the stage path
        stage_path = f"@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/{model_path}"
        
        # Call Cortex Analyst function
        # Note: In production, use SNOWFLAKE.CORTEX.ANALYST() function
        result = session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-70b',
                CONCAT(
                    'You are a helpful data analyst working with Snowflake. ',
                    'Generate a SQL query to answer this question. ',
                    'Return ONLY the SQL query, no explanations. ',
                    'Available tables: SEM_DEV.SEM_SALES views. ',
                    'Question: {question.replace("'", "''")}'
                )
            ) as RESPONSE
        """).to_pandas()
        
        if not result.empty:
            response = result['RESPONSE'].iloc[0]
            
            # Try to extract and execute SQL if it looks like a query
            if 'SELECT' in response.upper():
                try:
                    # Clean up the response to get just SQL
                    sql = response.strip()
                    if sql.startswith('```'):
                        sql = sql.split('```')[1]
                        if sql.startswith('sql'):
                            sql = sql[3:]
                        sql = sql.strip()
                    
                    # Execute the query
                    df = session.sql(sql).to_pandas()
                    return (f"Query executed successfully:\n```sql\n{sql}\n```", sql, df)
                except Exception as e:
                    return (f"Generated SQL (execution failed):\n{response}\n\nError: {str(e)}", None, None)
            
            return (response, None, None)
        return ("No response generated", None, None)
    except Exception as e:
        return (f"Error: {str(e)}", None, None)

# ============================================================================
# SIDEBAR
# ============================================================================

def render_sidebar():
    """Render the sidebar navigation"""
    with st.sidebar:
        # Snowflake logo placeholder
        st.markdown("""
        <div style="text-align: center; padding: 1rem 0 2rem 0;">
            <h1 style="color: #29B5E8; font-size: 2.5rem; margin: 0;">❄️</h1>
            <h2 style="color: white; font-size: 1.2rem; margin: 0.5rem 0 0 0;">Data Contracts</h2>
            <p style="color: #29B5E8; font-size: 0.8rem; margin: 0;">Enterprise Demo</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.divider()
        
        # Navigation
        page = st.radio(
            "Navigation",
            ["🤖 Cortex Analyst", "🔮 Horizon Dashboard", "📊 Contract Details", "ℹ️ About"],
            label_visibility="collapsed"
        )
        
        st.divider()
        
        # Quick stats
        st.markdown("### 📈 Quick Stats")
        
        kpis = get_dashboard_kpis()
        if not kpis.empty:
            col1, col2 = st.columns(2)
            with col1:
                if 'TOTAL_CONTRACTS' in kpis.columns:
                    st.metric("Contracts", kpis['TOTAL_CONTRACTS'].iloc[0])
                if 'ACTIVE_ALERTS' in kpis.columns:
                    st.metric("Alerts", kpis['ACTIVE_ALERTS'].iloc[0])
            with col2:
                if 'OVERALL_HEALTH_PCT' in kpis.columns:
                    st.metric("Health", f"{kpis['OVERALL_HEALTH_PCT'].iloc[0]:.0f}%")
                if 'SLA_COMPLIANCE_PCT' in kpis.columns:
                    st.metric("SLA", f"{kpis['SLA_COMPLIANCE_PCT'].iloc[0]:.0f}%")
        
        st.divider()
        
        # Footer
        st.markdown("""
        <div style="text-align: center; color: #666; font-size: 0.75rem;">
            <p>Powered by</p>
            <p style="color: #29B5E8;">Snowflake Horizon + Cortex</p>
        </div>
        """, unsafe_allow_html=True)
        
        return page

# ============================================================================
# CORTEX ANALYST PAGE
# ============================================================================

def render_cortex_page():
    """Render the Cortex Analyst chat interface"""
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🤖 Snowflake Cortex</h1>
        <p>Ask questions about your data in natural language</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Model selector
    col1, col2 = st.columns([2, 1])
    with col1:
        models = get_semantic_models()
        selected_model = st.selectbox(
            "Select Semantic Model",
            models,
            help="Choose which semantic model to query"
        )
    with col2:
        st.markdown("<br>", unsafe_allow_html=True)
        if st.button("🔄 Refresh Models"):
            st.cache_data.clear()
            st.rerun()
    
    st.divider()
    
    # Initialize chat history
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    # Display chat history
    for message in st.session_state.messages:
        role_class = "user" if message["role"] == "user" else "assistant"
        st.markdown(f"""
        <div class="chat-message {role_class}">
            <strong>{'You' if role_class == 'user' else '🤖 Cortex'}</strong><br>
            {message["content"]}
        </div>
        """, unsafe_allow_html=True)
        
        # Show dataframe if present
        if message.get("df") is not None and not message["df"].empty:
            st.dataframe(message["df"], use_container_width=True, hide_index=True)
    
    # Sample questions
    if not st.session_state.messages:
        st.markdown("### 💡 Sample Questions")
        
        sample_questions = {
            "sales_analytics_model.yaml": [
                "What was our total revenue last quarter?",
                "Show me revenue by region",
                "Which market segment generates the most revenue?",
                "What is our on-time delivery rate?"
            ],
            "customer_analytics_model.yaml": [
                "How many customers are at risk of churning?",
                "What is our average customer lifetime value?",
                "Show me customer segments by activity status",
                "Which region has the most premium customers?"
            ],
            "governance_analytics_model.yaml": [
                "Which contracts have SLA violations?",
                "What is our overall data quality score?",
                "Show me contracts with the most consumers",
                "What percentage of columns have governance tags?"
            ]
        }
        
        questions = sample_questions.get(selected_model, sample_questions["sales_analytics_model.yaml"])
        
        cols = st.columns(2)
        for i, q in enumerate(questions):
            with cols[i % 2]:
                if st.button(f"💬 {q}", key=f"sample_{i}", use_container_width=True):
                    st.session_state.pending_question = q
                    st.rerun()
    
    # Chat input
    st.divider()
    user_question = st.chat_input("Ask a question about your data...")
    
    # Handle pending question from sample buttons
    if "pending_question" in st.session_state:
        user_question = st.session_state.pending_question
        del st.session_state.pending_question
    
    if user_question:
        # Add user message
        st.session_state.messages.append({"role": "user", "content": user_question})
        
        # Get response
        with st.spinner("🤔 Thinking..."):
            response_text, sql_query, result_df = run_cortex_analyst(user_question, selected_model)
        
        # Build response content
        response_content = response_text
        
        # Store both text and dataframe if we have results
        st.session_state.messages.append({
            "role": "assistant", 
            "content": response_content,
            "df": result_df
        })
        
        st.rerun()
    
    # Clear chat button
    if st.session_state.messages:
        if st.button("🗑️ Clear Chat"):
            st.session_state.messages = []
            st.rerun()

# ============================================================================
# HORIZON DASHBOARD PAGE
# ============================================================================

def render_horizon_dashboard():
    """Render the Horizon governance dashboard"""
    
    # Header
    st.markdown("""
    <div class="horizon-header">
        <h1>🔮 Snowflake Horizon</h1>
        <p>Unified Governance & Observability Dashboard</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Fetch data
    kpis = get_dashboard_kpis()
    health = get_contract_health()
    alerts = get_active_alerts()
    sla = get_sla_compliance()
    tags = get_tag_coverage()
    
    # ─────────────────────────────────────────────────────────────────────────
    # KPI Row with Stoplights
    # ─────────────────────────────────────────────────────────────────────────
    
    st.markdown("### 🚦 System Health")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        health_pct = kpis['OVERALL_HEALTH_PCT'].iloc[0] if not kpis.empty and 'OVERALL_HEALTH_PCT' in kpis.columns else 0
        stoplight = "green" if health_pct >= 90 else ("yellow" if health_pct >= 70 else "red")
        st.markdown(f"""
        <div class="metric-card {'success' if stoplight == 'green' else ('warning' if stoplight == 'yellow' else 'error')}">
            <span class="stoplight {stoplight}"></span>
            <strong>Overall Health</strong>
            <h2 style="color: white; margin: 0.5rem 0;">{health_pct:.1f}%</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        sla_pct = kpis['SLA_COMPLIANCE_PCT'].iloc[0] if not kpis.empty and 'SLA_COMPLIANCE_PCT' in kpis.columns else 0
        stoplight = "green" if sla_pct >= 95 else ("yellow" if sla_pct >= 80 else "red")
        st.markdown(f"""
        <div class="metric-card {'success' if stoplight == 'green' else ('warning' if stoplight == 'yellow' else 'error')}">
            <span class="stoplight {stoplight}"></span>
            <strong>SLA Compliance</strong>
            <h2 style="color: white; margin: 0.5rem 0;">{sla_pct:.1f}%</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        quality_pct = kpis['QUALITY_SCORE_PCT'].iloc[0] if not kpis.empty and 'QUALITY_SCORE_PCT' in kpis.columns else 0
        stoplight = "green" if quality_pct >= 95 else ("yellow" if quality_pct >= 80 else "red")
        st.markdown(f"""
        <div class="metric-card {'success' if stoplight == 'green' else ('warning' if stoplight == 'yellow' else 'error')}">
            <span class="stoplight {stoplight}"></span>
            <strong>Data Quality</strong>
            <h2 style="color: white; margin: 0.5rem 0;">{quality_pct:.1f}%</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        alert_count = kpis['ACTIVE_ALERTS'].iloc[0] if not kpis.empty and 'ACTIVE_ALERTS' in kpis.columns else 0
        stoplight = "green" if alert_count == 0 else ("yellow" if alert_count <= 3 else "red")
        st.markdown(f"""
        <div class="metric-card {'success' if stoplight == 'green' else ('warning' if stoplight == 'yellow' else 'error')}">
            <span class="stoplight {stoplight}"></span>
            <strong>Active Alerts</strong>
            <h2 style="color: white; margin: 0.5rem 0;">{alert_count}</h2>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # ─────────────────────────────────────────────────────────────────────────
    # Charts Row
    # ─────────────────────────────────────────────────────────────────────────
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📈 SLA Compliance Trend")
        if not sla.empty and 'HOUR' in sla.columns and 'COMPLIANCE_RATE' in sla.columns:
            chart_data = sla[['HOUR', 'COMPLIANCE_RATE']].copy()
            chart_data = chart_data.sort_values('HOUR')
            st.line_chart(chart_data.set_index('HOUR'), color="#29B5E8")
        else:
            st.info("No SLA trend data available")
    
    with col2:
        st.markdown("### 🏷️ Tag Coverage by Type")
        if not tags.empty:
            # Create a simple bar chart
            if 'TAG_NAME' in tags.columns and 'COVERAGE_PCT' in tags.columns:
                chart_data = tags[['TAG_NAME', 'COVERAGE_PCT']].copy()
                st.bar_chart(chart_data.set_index('TAG_NAME'), color="#7C3AED")
            else:
                st.info("No tag coverage data available")
        else:
            st.info("No tag coverage data available")
    
    st.divider()
    
    # ─────────────────────────────────────────────────────────────────────────
    # Contract Health Table
    # ─────────────────────────────────────────────────────────────────────────
    
    st.markdown("### 📋 Contract Health Dashboard")
    
    if not health.empty:
        # Add stoplight column
        def get_health_indicator(row):
            score = row.get('QUALITY_SCORE', 0) if pd.notna(row.get('QUALITY_SCORE')) else 0
            if score >= 90:
                return "🟢"
            elif score >= 70:
                return "🟡"
            else:
                return "🔴"
        
        display_df = health.copy()
        display_df['Status'] = display_df.apply(get_health_indicator, axis=1)
        
        # Select and reorder columns
        display_cols = ['Status', 'CONTRACT_ID', 'OVERALL_HEALTH', 'QUALITY_SCORE', 
                       'FRESHNESS_STATUS', 'CONSUMER_COUNT']
        display_cols = [c for c in display_cols if c in display_df.columns]
        
        st.dataframe(
            display_df[display_cols],
            use_container_width=True,
            hide_index=True
        )
    else:
        st.info("No contract health data available")
    
    st.divider()
    
    # ─────────────────────────────────────────────────────────────────────────
    # Active Alerts
    # ─────────────────────────────────────────────────────────────────────────
    
    st.markdown("### 🚨 Active Alerts")
    
    if not alerts.empty:
        for _, alert in alerts.iterrows():
            severity = alert.get('SEVERITY', 'INFO')
            icon = "🔴" if severity == 'ERROR' else ("🟡" if severity == 'WARNING' else "🔵")
            
            with st.expander(f"{icon} {alert.get('TITLE', 'Alert')}", expanded=False):
                st.write(f"**Contract:** {alert.get('CONTRACT_ID', 'N/A')}")
                st.write(f"**Type:** {alert.get('ALERT_TYPE', 'N/A')}")
                st.write(f"**Message:** {alert.get('MESSAGE', 'N/A')}")
                st.write(f"**Created:** {alert.get('CREATED_AT', 'N/A')}")
    else:
        st.success("✅ No active alerts - all systems healthy!")

# ============================================================================
# CONTRACT DETAILS PAGE
# ============================================================================

def render_contract_details():
    """Render contract details page"""
    
    st.markdown("""
    <div class="main-header">
        <h1>📊 Contract Details</h1>
        <p>Explore individual contract configurations and metrics</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Get contracts
    session = get_session()
    try:
        contracts_df = session.sql("""
            SELECT CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, 
                   PRODUCER_SYSTEM, DESCRIPTION
            FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
            WHERE STATUS = 'active'
            ORDER BY CONTRACT_ID
        """).to_pandas()
    except:
        contracts_df = pd.DataFrame()
    
    if not contracts_df.empty:
        # Contract selector
        selected_contract = st.selectbox(
            "Select Contract",
            contracts_df['CONTRACT_ID'].tolist()
        )
        
        if selected_contract:
            contract_info = contracts_df[contracts_df['CONTRACT_ID'] == selected_contract].iloc[0]
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("### Contract Information")
                st.write(f"**ID:** {contract_info['CONTRACT_ID']}")
                st.write(f"**Type:** {contract_info['CONTRACT_TYPE']}")
                st.write(f"**Version:** {contract_info['VERSION']}")
                st.write(f"**Status:** {contract_info['STATUS']}")
                st.write(f"**Producer:** {contract_info['PRODUCER_SYSTEM']}")
                st.write(f"**Description:** {contract_info['DESCRIPTION']}")
            
            with col2:
                st.markdown("### Consumers")
                try:
                    consumers = session.sql(f"""
                        SELECT CONSUMER_SYSTEM, CONSUMER_EMAIL, USE_CASE
                        FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
                        WHERE CONTRACT_ID = '{selected_contract}'
                    """).to_pandas()
                    
                    if not consumers.empty:
                        st.dataframe(consumers, use_container_width=True, hide_index=True)
                    else:
                        st.info("No registered consumers")
                except:
                    st.info("Unable to load consumers")
            
            st.divider()
            
            # Quality Rules
            st.markdown("### Quality Rules")
            try:
                rules = session.sql(f"""
                    SELECT RULE_ID, RULE_NAME, RULE_TYPE, SEVERITY, ENABLED
                    FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES
                    WHERE CONTRACT_ID = '{selected_contract}'
                """).to_pandas()
                
                if not rules.empty:
                    st.dataframe(rules, use_container_width=True, hide_index=True)
                else:
                    st.info("No quality rules defined")
            except:
                st.info("Unable to load quality rules")
    else:
        st.info("No contracts available")

# ============================================================================
# ABOUT PAGE
# ============================================================================

def render_about():
    """Render about page"""
    
    st.markdown("""
    <div class="main-header">
        <h1>ℹ️ About This Demo</h1>
        <p>Enterprise Architecture Guide for the Snowflake Data Cloud</p>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("""
    ## 🎯 What This Demo Shows
    
    This application demonstrates a **contract-first data architecture** built on:
    
    ### Snowflake Horizon (Governance)
    - **Object Tagging** - DATA_CLASSIFICATION, PII_TYPE, AI_ALLOWED tags
    - **Tag-Based Masking** - Dynamic PII protection
    - **Access History** - Complete audit trail
    - **Data Classification** - Automatic sensitivity detection
    
    ### Snowflake Cortex (AI)
    - **Cortex Analyst** - Natural language to SQL
    - **LLM Functions** - COMPLETE, SUMMARIZE, CLASSIFY
    - **ML Functions** - FORECAST, ANOMALY_DETECTION
    - **Semantic Models** - YAML definitions for each domain
    
    ### Data Architecture
    - **Three-Layer Design** - RAW → CURATED → SEMANTIC
    - **Dynamic Tables** - Automated transformation pipelines
    - **Data Contracts** - Schema, SLAs, quality rules as code
    - **Observability** - Real-time health monitoring
    
    ---
    
    ## 🏗️ Architecture
    
    ```
    People → Data → Governance → Automation
    ```
    
    Each layer inherits stability from the layer before it.
    
    ---
    
    ## 📚 Resources
    
    - [Snowflake Horizon](https://www.snowflake.com/en/data-cloud/horizon/)
    - [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
    - [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
    - [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
    
    ---
    
    *Built with ❄️ Streamlit in Snowflake*
    """)

# ============================================================================
# MAIN APP
# ============================================================================

def main():
    """Main application entry point"""
    
    # Render sidebar and get selected page
    page = render_sidebar()
    
    # Render selected page
    if page == "🤖 Cortex Analyst":
        render_cortex_page()
    elif page == "🔮 Horizon Dashboard":
        render_horizon_dashboard()
    elif page == "📊 Contract Details":
        render_contract_details()
    elif page == "ℹ️ About":
        render_about()

if __name__ == "__main__":
    main()
