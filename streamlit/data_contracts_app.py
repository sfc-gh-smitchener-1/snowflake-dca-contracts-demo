# ============================================================================
# DATA CONTRACTS DEMO - Streamlit in Snowflake Application
# ============================================================================
# A comprehensive dashboard for:
#   1. Snowflake Cortex Analyst - Natural language queries on semantic views
#   2. Snowflake Horizon - Governance & observability dashboard
#
# Uses the Cortex Analyst API for native semantic view querying
# ============================================================================

import streamlit as st
import pandas as pd
import requests
import json
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
# SNOWFLAKE LIGHT THEME STYLING
# ============================================================================

SNOWFLAKE_BLUE = "#29B5E8"
SNOWFLAKE_DARK_BLUE = "#11567F"
SNOWFLAKE_LIGHT_BLUE = "#E3F5FC"
HORIZON_PURPLE = "#6E56CF"
SUCCESS_GREEN = "#18794E"
WARNING_AMBER = "#AD5700"
ERROR_RED = "#CD2B31"

st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
    
    .stApp {
        background: linear-gradient(180deg, #FFFFFF 0%, #F0F9FF 100%);
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    }
    
    [data-testid="stSidebar"] {
        background: linear-gradient(180deg, #11567F 0%, #0D3D5C 100%);
    }
    
    [data-testid="stSidebar"] * {
        color: white !important;
    }
    
    [data-testid="stSidebar"] .stRadio label {
        color: white !important;
        font-weight: 500;
    }
    
    .main-header {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(41, 181, 232, 0.3);
    }
    
    .main-header h1 { margin: 0; font-size: 1.75rem; font-weight: 700; }
    .main-header p { margin: 0.5rem 0 0 0; opacity: 0.9; font-size: 0.95rem; }
    
    .horizon-header {
        background: linear-gradient(135deg, #6E56CF 0%, #29B5E8 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(110, 86, 207, 0.3);
    }
    
    .horizon-header h1 { margin: 0; font-size: 1.75rem; font-weight: 700; }
    .horizon-header p { margin: 0.5rem 0 0 0; opacity: 0.9; }
    
    .metric-card {
        background: white;
        border-radius: 12px;
        padding: 1.25rem;
        border-left: 4px solid #29B5E8;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
        margin-bottom: 0.5rem;
    }
    
    .metric-card.success { border-left-color: #18794E; }
    .metric-card.warning { border-left-color: #AD5700; }
    .metric-card.error { border-left-color: #CD2B31; }
    
    .metric-card strong {
        color: #64748B;
        font-size: 0.8rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .metric-card h2 {
        color: #0F172A !important;
        margin: 0.5rem 0 0 0;
        font-size: 1.75rem;
        font-weight: 700;
    }
    
    .stoplight {
        display: inline-block;
        width: 14px;
        height: 14px;
        border-radius: 50%;
        margin-right: 8px;
        vertical-align: middle;
    }
    
    .stoplight.green { background: #18794E; box-shadow: 0 0 8px rgba(24,121,78,0.5); }
    .stoplight.yellow { background: #AD5700; box-shadow: 0 0 8px rgba(173,87,0,0.5); }
    .stoplight.red { background: #CD2B31; box-shadow: 0 0 8px rgba(205,43,49,0.5); }
    
    .chat-bubble {
        padding: 15px;
        border-radius: 12px;
        margin-bottom: 10px;
    }
    
    .user-bubble {
        background: #E3F5FC;
        border-left: 5px solid #29B5E8;
    }
    
    .assistant-bubble {
        background: #F1F5F9;
        border-left: 5px solid #6E56CF;
    }
    
    .stButton > button {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        color: white;
        border: none;
        border-radius: 8px;
        font-weight: 500;
    }
    
    .stButton > button:hover {
        box-shadow: 0 4px 12px rgba(41, 181, 232, 0.4);
        transform: translateY(-1px);
    }
    
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

# ============================================================================
# SESSION & CORTEX ANALYST API
# ============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session"""
    return get_active_session()

def call_cortex_analyst(prompt: str, semantic_view: str):
    """Calls the Cortex Analyst API using the SiS session token."""
    session = get_session()
    
    try:
        # Get host from session
        host = session.connection.host
        
        # API Endpoint for Cortex Analyst
        url = f"https://{host}/api/v2/cortex/analyst/message"
        
        # Payload for Semantic Views
        request_body = {
            "messages": [
                {"role": "user", "content": [{"type": "text", "text": prompt}]}
            ],
            "semantic_model_file": f"semantic_view://{semantic_view}"
        }
        
        # Use the native Snowflake session token for authentication
        headers = {
            "Authorization": f'Snowflake Token="{session._conn._token}"',
            "Content-Type": "application/json",
            "Accept": "application/json"
        }

        response = requests.post(url, json=request_body, headers=headers)
        
        if response.status_code == 200:
            return response.json(), None
        else:
            return None, f"API Error {response.status_code}: {response.text}"
            
    except Exception as e:
        return None, f"Connection Error: {str(e)}"

def execute_sql(sql: str):
    """Execute SQL and return DataFrame"""
    session = get_session()
    try:
        return session.sql(sql).to_pandas(), None
    except Exception as e:
        return None, str(e)

# ============================================================================
# DATA FETCHING FOR DASHBOARD
# ============================================================================

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
    except:
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
    except:
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
    except:
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
    except:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_tag_coverage():
    """Fetch tag coverage"""
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
    except:
        return pd.DataFrame()

@st.cache_data(ttl=300)
def get_semantic_views():
    """List available semantic views"""
    session = get_session()
    try:
        df = session.sql("SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV").to_pandas()
        if not df.empty and 'name' in df.columns:
            views = []
            for _, row in df.iterrows():
                schema = row.get('schema_name', '')
                name = row.get('name', '')
                if schema and name:
                    views.append(f"SEM_DEV.{schema}.{name}")
            return views if views else get_default_semantic_views()
        return get_default_semantic_views()
    except:
        return get_default_semantic_views()

def get_default_semantic_views():
    """Return default list of semantic views"""
    return [
        'SEM_DEV.SEM_SALES.SALES_ANALYTICS',
        'SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS', 
        'SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS',
        'SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS',
        'SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS'
    ]

# ============================================================================
# SIDEBAR
# ============================================================================

def render_sidebar():
    """Render the sidebar navigation"""
    with st.sidebar:
        st.markdown("""
        <div style="text-align: center; padding: 1rem 0 1.5rem 0;">
            <div style="font-size: 3rem; margin-bottom: 0.5rem;">❄️</div>
            <h2 style="color: white; font-size: 1.3rem; margin: 0; font-weight: 700;">Data Contracts</h2>
            <p style="color: #29B5E8; font-size: 0.85rem; margin: 0.25rem 0 0 0;">Enterprise Demo</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.divider()
        
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
                    val = kpis['TOTAL_CONTRACTS'].iloc[0]
                    st.metric("Contracts", int(val) if pd.notna(val) else 0)
                if 'ACTIVE_ALERTS' in kpis.columns:
                    val = kpis['ACTIVE_ALERTS'].iloc[0]
                    st.metric("Alerts", int(val) if pd.notna(val) else 0)
            with col2:
                if 'OVERALL_HEALTH_PCT' in kpis.columns:
                    val = kpis['OVERALL_HEALTH_PCT'].iloc[0]
                    st.metric("Health", f"{val:.0f}%" if pd.notna(val) else "N/A")
                if 'SLA_COMPLIANCE_PCT' in kpis.columns:
                    val = kpis['SLA_COMPLIANCE_PCT'].iloc[0]
                    st.metric("SLA", f"{val:.0f}%" if pd.notna(val) else "N/A")
        else:
            st.info("Loading stats...")
        
        st.divider()
        
        st.markdown("""
        <div style="text-align: center; padding-top: 1rem;">
            <p style="color: rgba(255,255,255,0.6); font-size: 0.75rem; margin: 0;">Powered by</p>
            <p style="color: #29B5E8; font-size: 0.85rem; margin: 0.25rem 0 0 0; font-weight: 500;">Snowflake Horizon + Cortex</p>
        </div>
        """, unsafe_allow_html=True)
        
        return page

# ============================================================================
# CORTEX ANALYST PAGE
# ============================================================================

def render_cortex_page():
    """Render the Cortex Analyst chat interface"""
    
    st.markdown("""
    <div class="main-header">
        <h1>🤖 Snowflake Cortex Analyst</h1>
        <p>Ask questions about your data using natural language</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Semantic View selector
    col1, col2 = st.columns([3, 1])
    with col1:
        views = get_semantic_views()
        selected_view = st.selectbox(
            "Select Semantic View",
            views,
            help="Choose which semantic view to query"
        )
    with col2:
        st.write("")
        if st.button("🔄 Refresh", use_container_width=True):
            st.cache_data.clear()
            st.rerun()
    
    st.divider()
    
    # Initialize chat history
    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []
    
    # Display chat history
    for chat in st.session_state.chat_history:
        with st.chat_message(chat["role"]):
            st.markdown(chat["content"])
            if "sql" in chat and chat["sql"]:
                with st.expander("View Generated SQL"):
                    st.code(chat["sql"], language="sql")
            if "df" in chat and chat["df"] is not None and not chat["df"].empty:
                st.dataframe(chat["df"], use_container_width=True)
    
    # Sample questions for new users
    if not st.session_state.chat_history:
        st.markdown("### 💡 Sample Questions")
        
        sample_questions = {
            "SEM_DEV.SEM_SALES.SALES_ANALYTICS": [
                "What is the total revenue by region?",
                "Show me the top 10 brands by revenue",
                "What is the average delivery time by market segment?",
                "How many orders were placed each year?"
            ],
            "SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS": [
                "How many customers are in each activity status?",
                "What is the average lifetime value by customer tier?",
                "Show customer count by region",
                "What is the total revenue by market segment?"
            ],
            "SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS": [
                "What is the total revenue by brand?",
                "Show inventory levels by price tier",
                "How many products are there by manufacturer?",
                "What are the top selling products?"
            ],
            "SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS": [
                "What is the average delivery time by supplier?",
                "Show total revenue by region",
                "What is the inventory by supplier tier?",
                "How many suppliers are in each nation?"
            ],
            "SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS": [
                "How many contracts are there by status?",
                "Show alert counts by type",
                "What is the breakdown by contract type?",
                "How many rules are there by severity?"
            ]
        }
        
        questions = sample_questions.get(selected_view, [
            "Show me a summary of the data",
            "What are the key metrics?",
            "What are the totals by category?",
            "Show me the top 10 items"
        ])
        
        cols = st.columns(2)
        for i, q in enumerate(questions):
            with cols[i % 2]:
                if st.button(f"💬 {q}", key=f"sample_{i}", use_container_width=True):
                    process_question(q, selected_view)
                    st.rerun()
    
    # Chat input
    if prompt := st.chat_input("Ask a question about your data..."):
        process_question(prompt, selected_view)
        st.rerun()
    
    # Clear chat button
    if st.session_state.chat_history:
        if st.button("🗑️ Clear Chat", key="clear_chat"):
            st.session_state.chat_history = []
            st.rerun()

def process_question(prompt: str, semantic_view: str):
    """Process a user question via Cortex Analyst API"""
    
    # Add user message to history
    st.session_state.chat_history.append({
        "role": "user",
        "content": prompt
    })
    
    # Call Cortex Analyst API
    api_response, error = call_cortex_analyst(prompt, semantic_view)
    
    if error:
        st.session_state.chat_history.append({
            "role": "assistant",
            "content": f"❌ {error}"
        })
        return
    
    if api_response:
        # Extract response content
        msg_content = api_response.get("message", {}).get("content", [])
        sql_query = None
        explanation = ""
        
        for part in msg_content:
            if part.get("type") == "text":
                explanation += part.get("text", "")
            elif part.get("type") == "sql":
                sql_query = part.get("statement", "")
        
        # Execute SQL if present
        result_df = None
        if sql_query:
            result_df, sql_error = execute_sql(sql_query)
            if sql_error:
                explanation += f"\n\n⚠️ SQL Error: {sql_error}"
        
        # Store in history
        st.session_state.chat_history.append({
            "role": "assistant",
            "content": explanation if explanation else "✅ Query executed successfully",
            "sql": sql_query,
            "df": result_df
        })

# ============================================================================
# HORIZON DASHBOARD PAGE
# ============================================================================

def render_horizon_dashboard():
    """Render the Horizon governance dashboard"""
    
    st.markdown("""
    <div class="horizon-header">
        <h1>🔮 Snowflake Horizon</h1>
        <p>Unified Governance & Observability Dashboard</p>
    </div>
    """, unsafe_allow_html=True)
    
    kpis = get_dashboard_kpis()
    health = get_contract_health()
    alerts = get_active_alerts()
    sla = get_sla_compliance()
    tags = get_tag_coverage()
    
    # KPI Row with Stoplights
    st.markdown("### 🚦 System Health")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        health_pct = kpis['OVERALL_HEALTH_PCT'].iloc[0] if not kpis.empty and 'OVERALL_HEALTH_PCT' in kpis.columns and pd.notna(kpis['OVERALL_HEALTH_PCT'].iloc[0]) else 0
        stoplight = "green" if health_pct >= 90 else ("yellow" if health_pct >= 70 else "red")
        card_class = "success" if stoplight == "green" else ("warning" if stoplight == "yellow" else "error")
        st.markdown(f"""
        <div class="metric-card {card_class}">
            <span class="stoplight {stoplight}"></span>
            <strong>Overall Health</strong>
            <h2>{health_pct:.0f}%</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        sla_pct = kpis['SLA_COMPLIANCE_PCT'].iloc[0] if not kpis.empty and 'SLA_COMPLIANCE_PCT' in kpis.columns and pd.notna(kpis['SLA_COMPLIANCE_PCT'].iloc[0]) else 0
        stoplight = "green" if sla_pct >= 95 else ("yellow" if sla_pct >= 80 else "red")
        card_class = "success" if stoplight == "green" else ("warning" if stoplight == "yellow" else "error")
        st.markdown(f"""
        <div class="metric-card {card_class}">
            <span class="stoplight {stoplight}"></span>
            <strong>SLA Compliance</strong>
            <h2>{sla_pct:.0f}%</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        quality_pct = kpis['QUALITY_SCORE_PCT'].iloc[0] if not kpis.empty and 'QUALITY_SCORE_PCT' in kpis.columns and pd.notna(kpis['QUALITY_SCORE_PCT'].iloc[0]) else 0
        stoplight = "green" if quality_pct >= 95 else ("yellow" if quality_pct >= 80 else "red")
        card_class = "success" if stoplight == "green" else ("warning" if stoplight == "yellow" else "error")
        st.markdown(f"""
        <div class="metric-card {card_class}">
            <span class="stoplight {stoplight}"></span>
            <strong>Data Quality</strong>
            <h2>{quality_pct:.0f}%</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        alert_count = int(kpis['ACTIVE_ALERTS'].iloc[0]) if not kpis.empty and 'ACTIVE_ALERTS' in kpis.columns and pd.notna(kpis['ACTIVE_ALERTS'].iloc[0]) else 0
        stoplight = "green" if alert_count == 0 else ("yellow" if alert_count <= 3 else "red")
        card_class = "success" if stoplight == "green" else ("warning" if stoplight == "yellow" else "error")
        st.markdown(f"""
        <div class="metric-card {card_class}">
            <span class="stoplight {stoplight}"></span>
            <strong>Active Alerts</strong>
            <h2>{alert_count}</h2>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # Charts Row
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📈 SLA Compliance Trend")
        if not sla.empty and 'HOUR' in sla.columns and 'COMPLIANCE_RATE' in sla.columns:
            chart_data = sla[['HOUR', 'COMPLIANCE_RATE']].copy()
            chart_data = chart_data.sort_values('HOUR')
            st.line_chart(chart_data.set_index('HOUR'))
        else:
            st.info("📊 No SLA trend data available yet.")
    
    with col2:
        st.markdown("### 🏷️ Governance Tag Coverage")
        if not tags.empty and 'TAG_NAME' in tags.columns and 'COVERAGE_PCT' in tags.columns:
            chart_data = tags[['TAG_NAME', 'COVERAGE_PCT']].copy()
            st.bar_chart(chart_data.set_index('TAG_NAME'))
        else:
            st.info("🏷️ No tag coverage data available yet.")
    
    st.divider()
    
    # Contract Health Table
    st.markdown("### 📋 Contract Health Dashboard")
    
    if not health.empty:
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
        
        display_cols = ['Status', 'CONTRACT_ID', 'OVERALL_HEALTH', 'QUALITY_SCORE', 
                       'FRESHNESS_STATUS', 'CONSUMER_COUNT']
        display_cols = [c for c in display_cols if c in display_df.columns]
        
        if display_cols:
            st.dataframe(display_df[display_cols], use_container_width=True)
        else:
            st.info("📋 Contract health data structure differs from expected.")
    else:
        st.info("📋 No contract health data available yet.")
    
    st.divider()
    
    # Active Alerts
    st.markdown("### 🚨 Active Alerts")
    
    if not alerts.empty:
        for _, alert in alerts.iterrows():
            severity = alert.get('SEVERITY', 'INFO')
            if severity in ['CRITICAL', 'ERROR']:
                icon = "🔴"
            elif severity == 'WARNING':
                icon = "🟡"
            else:
                icon = "🔵"
            
            title = alert.get('TITLE', 'Alert')
            with st.expander(f"{icon} {title}", expanded=False):
                col1, col2 = st.columns(2)
                with col1:
                    st.write(f"**Contract:** {alert.get('CONTRACT_ID', 'N/A')}")
                    st.write(f"**Type:** {alert.get('ALERT_TYPE', 'N/A')}")
                with col2:
                    st.write(f"**Severity:** {severity}")
                    st.write(f"**Created:** {alert.get('CREATED_AT', 'N/A')}")
                st.write(f"**Message:** {alert.get('MESSAGE', 'N/A')}")
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
        selected_contract = st.selectbox(
            "Select Contract",
            contracts_df['CONTRACT_ID'].tolist()
        )
        
        if selected_contract:
            contract_info = contracts_df[contracts_df['CONTRACT_ID'] == selected_contract].iloc[0]
            
            st.divider()
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("### 📄 Contract Information")
                st.markdown(f"""
                | Property | Value |
                |----------|-------|
                | **ID** | `{contract_info['CONTRACT_ID']}` |
                | **Type** | {contract_info['CONTRACT_TYPE']} |
                | **Version** | {contract_info['VERSION']} |
                | **Status** | {contract_info['STATUS']} |
                | **Producer** | {contract_info['PRODUCER_SYSTEM']} |
                """)
                
                if contract_info['DESCRIPTION']:
                    st.markdown(f"**Description:** {contract_info['DESCRIPTION']}")
            
            with col2:
                st.markdown("### 👥 Consumers")
                try:
                    consumers = session.sql(f"""
                        SELECT CONSUMER_SYSTEM, CONSUMER_EMAIL, USE_CASE
                        FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
                        WHERE CONTRACT_ID = '{selected_contract}'
                    """).to_pandas()
                    
                    if not consumers.empty:
                        st.dataframe(consumers, use_container_width=True)
                    else:
                        st.info("No registered consumers")
                except:
                    st.info("Unable to load consumer data")
            
            st.divider()
            
            st.markdown("### ✅ Quality Rules")
            try:
                rules = session.sql(f"""
                    SELECT RULE_ID, RULE_NAME, RULE_TYPE, SEVERITY, ENABLED
                    FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES
                    WHERE CONTRACT_ID = '{selected_contract}'
                """).to_pandas()
                
                if not rules.empty:
                    st.dataframe(rules, use_container_width=True)
                else:
                    st.info("No quality rules defined")
            except:
                st.info("Unable to load quality rules")
    else:
        st.info("📋 No active contracts found. Run the demo setup scripts to create contracts.")

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
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        ### 🔮 Snowflake Horizon
        
        This demo leverages Horizon unified governance:
        
        - **Object Tagging** — DATA_CLASSIFICATION, PII_TYPE, AI_ALLOWED
        - **Tag-Based Masking** — Dynamic PII protection at query time
        - **Access History** — Complete audit trail of data access
        - **Data Classification** — Automatic sensitivity detection
        """)
        
        st.markdown("""
        ### 🏗️ Data Architecture
        
        - **Three-Layer Design** — RAW → CURATED → SEMANTIC
        - **Dynamic Tables** — Automated transformation pipelines
        - **Data Contracts** — Schema, SLAs, quality rules as code
        - **Observability** — Real-time health monitoring
        """)
    
    with col2:
        st.markdown("""
        ### 🤖 Snowflake Cortex
        
        AI capabilities for governed data:
        
        - **Cortex Analyst** — Natural language to SQL via API
        - **Semantic Views** — Native semantic model definitions
        - **LLM Functions** — COMPLETE, SUMMARIZE, TRANSLATE
        - **ML Functions** — FORECAST, ANOMALY_DETECTION
        """)
        
        st.markdown("""
        ### 📚 Resources
        
        - [Snowflake Horizon](https://www.snowflake.com/horizon/)
        - [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
        - [Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic)
        - [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
        """)
    
    st.divider()
    
    st.markdown("""
    ### 🎯 Architecture Principle
    
    > *"AI, governance, and automation cannot scale unless business intent is explicit, portable, and enforceable by the data platform itself."*
    
    **Dependency Chain:** `People → Data → Governance → Automation`
    """)
    
    st.markdown("---")
    st.markdown("*Built with ❄️ Streamlit in Snowflake*")

# ============================================================================
# MAIN APP
# ============================================================================

def main():
    """Main application entry point"""
    page = render_sidebar()
    
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
