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
# SNOWFLAKE LIGHT THEME STYLING
# ============================================================================

# Snowflake brand colors - Light theme with dark accents
SNOWFLAKE_BLUE = "#29B5E8"
SNOWFLAKE_DARK_BLUE = "#11567F"
SNOWFLAKE_LIGHT_BLUE = "#E3F5FC"
HORIZON_PURPLE = "#6E56CF"
SUCCESS_GREEN = "#18794E"
WARNING_AMBER = "#AD5700"
ERROR_RED = "#CD2B31"

# Custom CSS for Snowflake branding - LIGHT THEME
st.markdown("""
<style>
    /* Import clean font */
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
    
    /* Main app styling - Light background */
    .stApp {
        background: linear-gradient(180deg, #FFFFFF 0%, #F0F9FF 100%);
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    }
    
    /* Sidebar styling - Snowflake blue gradient */
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
    
    [data-testid="stSidebar"] .stMetric label {
        color: rgba(255,255,255,0.7) !important;
    }
    
    [data-testid="stSidebar"] .stMetric [data-testid="stMetricValue"] {
        color: white !important;
    }
    
    /* Header styling - Cortex */
    .main-header {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(41, 181, 232, 0.3);
    }
    
    .main-header h1 {
        margin: 0;
        font-size: 1.75rem;
        font-weight: 700;
        letter-spacing: -0.02em;
    }
    
    .main-header p {
        margin: 0.5rem 0 0 0;
        opacity: 0.9;
        font-size: 0.95rem;
    }
    
    /* Horizon header - Purple gradient */
    .horizon-header {
        background: linear-gradient(135deg, #6E56CF 0%, #29B5E8 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(110, 86, 207, 0.3);
    }
    
    .horizon-header h1 {
        margin: 0;
        font-size: 1.75rem;
        font-weight: 700;
    }
    
    .horizon-header p {
        margin: 0.5rem 0 0 0;
        opacity: 0.9;
    }
    
    /* Metric cards - Light with colored borders */
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
    
    /* Stoplight indicators */
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
    
    /* Chat styling - Light theme */
    .chat-message {
        padding: 1rem 1.25rem;
        border-radius: 12px;
        margin-bottom: 1rem;
        line-height: 1.5;
    }
    
    .chat-message.user {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        color: white;
        margin-left: 15%;
        box-shadow: 0 2px 8px rgba(41, 181, 232, 0.3);
    }
    
    .chat-message.assistant {
        background: white;
        color: #0F172A;
        margin-right: 15%;
        border: 1px solid #E2E8F0;
        box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }
    
    .chat-message strong {
        display: block;
        margin-bottom: 0.5rem;
        font-weight: 600;
    }
    
    /* Section headers */
    .section-header {
        color: #0F172A;
        font-size: 1.1rem;
        font-weight: 600;
        margin: 1.5rem 0 1rem 0;
        padding-bottom: 0.5rem;
        border-bottom: 2px solid #E2E8F0;
    }
    
    /* Data tables */
    .stDataFrame {
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    }
    
    /* Buttons */
    .stButton > button {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        color: white;
        border: none;
        border-radius: 8px;
        font-weight: 500;
        transition: all 0.2s ease;
    }
    
    .stButton > button:hover {
        box-shadow: 0 4px 12px rgba(41, 181, 232, 0.4);
        transform: translateY(-1px);
    }
    
    /* Sample question buttons */
    .sample-btn {
        background: white !important;
        color: #11567F !important;
        border: 1px solid #E2E8F0 !important;
        border-radius: 8px;
        padding: 0.75rem 1rem;
        text-align: left;
        transition: all 0.2s ease;
    }
    
    .sample-btn:hover {
        border-color: #29B5E8 !important;
        background: #F0F9FF !important;
    }
    
    /* Expander styling */
    .streamlit-expanderHeader {
        background: white;
        border-radius: 8px;
    }
    
    /* Info/Success boxes */
    .stAlert {
        border-radius: 8px;
    }
    
    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    
    /* Custom scrollbar - Light theme */
    ::-webkit-scrollbar {
        width: 8px;
        height: 8px;
    }
    
    ::-webkit-scrollbar-track {
        background: #F1F5F9;
    }
    
    ::-webkit-scrollbar-thumb {
        background: #CBD5E1;
        border-radius: 4px;
    }
    
    ::-webkit-scrollbar-thumb:hover {
        background: #94A3B8;
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
    
    # Map model to available tables - these are the ACTUAL views that exist
    model_tables = {
        "sales_analytics_model.yaml": """
Available views:
1. SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS - Line item level sales data
   Columns: ORDER_DATE, YEAR, QUARTER, MONTH, REGION_NAME, NATION_NAME, MARKET_SEGMENT, CUSTOMER_KEY, PART_NAME, BRAND, SUPPLIER_NAME, QUANTITY, GROSS_REVENUE, NET_REVENUE, DISCOUNT_AMOUNT, DELIVERY_DAYS, IS_RETURNED, IS_LATE_DELIVERY

2. SEM_DEV.SEM_SALES.VW_SALES_SUMMARY - Aggregated sales by dimensions
   Columns: YEAR, QUARTER, MONTH, REGION_NAME, MARKET_SEGMENT, CUSTOMER_TIER, MANUFACTURER, BRAND, ORDER_COUNT, CUSTOMER_COUNT, GROSS_REVENUE, NET_REVENUE, AVG_ORDER_VALUE, RETURN_RATE_PCT, LATE_DELIVERY_RATE_PCT, AVG_DELIVERY_DAYS
""",
        "customer_analytics_model.yaml": """
Available views:
1. SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS - Customer RFM and segmentation
   Columns: CUSTOMER_ID, MARKET_SEGMENT, CUSTOMER_TIER, REGION_NAME, NATION_NAME, TOTAL_ORDERS, LIFETIME_VALUE, AVG_ORDER_VALUE, FIRST_ORDER_DATE, LAST_ORDER_DATE, RECENCY_DAYS, TENURE_DAYS, ACTIVITY_STATUS, RECENCY_SCORE, FREQUENCY_SCORE, MONETARY_SCORE, CUSTOMER_SEGMENT
""",
        "supplier_analytics_model.yaml": """
Available views:
1. SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS - Supplier performance metrics
   Columns: SUPPLIER_KEY, SUPPLIER_NAME, SUPPLIER_TIER, NATION_NAME, REGION_NAME, ORDER_COUNT, TOTAL_QUANTITY_SOLD, GROSS_REVENUE, NET_REVENUE, RETURN_COUNT, RETURN_RATE_PCT, LATE_DELIVERIES, LATE_DELIVERY_RATE_PCT, AVG_DELIVERY_DAYS, PARTS_SUPPLIED, TOTAL_INVENTORY, SUPPLIER_SCORE, SUPPLIER_CATEGORY
""",
        "product_analytics_model.yaml": """
Available views:
1. SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS - Product performance and inventory
   Columns: PART_KEY, PART_NAME, MANUFACTURER, BRAND, PART_TYPE, RETAIL_PRICE, PRICE_TIER, ORDER_COUNT, TOTAL_QUANTITY_SOLD, GROSS_REVENUE, NET_REVENUE, RETURN_RATE_PCT, INVENTORY_ON_HAND, AVG_SUPPLY_COST, GROSS_MARGIN, GROSS_MARGIN_PCT, INVENTORY_STATUS, PERFORMANCE_TIER
""",
        "governance_analytics_model.yaml": """
Available views:
1. GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD - Contract health metrics
   Columns: CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, QUALITY_SCORE, FRESHNESS_STATUS, CONSUMER_COUNT, OVERALL_HEALTH, OVERALL_SCORE

2. GOVERNANCE.OBSERVABILITY.VW_DASHBOARD_KPIS - Summary KPIs
   Columns: ACTIVE_CONTRACTS, AVG_HEALTH_SCORE, AVG_QUALITY_SCORE, SLA_COMPLIANCE_24H, CRITICAL_ALERTS, WARNING_ALERTS

3. GOVERNANCE.OBSERVABILITY.VW_ACTIVE_ALERTS - Active alerts
   Columns: ALERT_ID, CONTRACT_ID, ALERT_TYPE, SEVERITY, TITLE, MESSAGE, STATUS, CREATED_AT
"""
    }
    
    schema_context = model_tables.get(model_path, """
Available views:
1. SEM_DEV.SEM_SALES.VW_SALES_SUMMARY - Aggregated sales data
2. SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS - Customer analytics
3. SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS - Supplier performance
4. SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS - Product analytics
""")
    
    try:
        # Call Cortex Complete function with better context
        escaped_question = question.replace("'", "''").replace("\\", "\\\\")
        escaped_context = schema_context.replace("'", "''").replace("\\", "\\\\")
        
        result = session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-70b',
                'You are a SQL expert for Snowflake. Generate ONLY a valid SQL SELECT query. No explanations, no markdown, just the raw SQL query.

{escaped_context}

Important: Always use fully qualified table names like SEM_DEV.SEM_SALES.VW_SALES_SUMMARY or GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD.

Question: {escaped_question}

SQL Query:'
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
                    return (f"✅ Query executed successfully", sql, df)
                except Exception as e:
                    return (f"Generated SQL:\n```\n{response}\n```\n\n⚠️ Execution error: {str(e)}", None, None)
            
            return (response, None, None)
        return ("No response generated", None, None)
    except Exception as e:
        return (f"❌ Error: {str(e)}", None, None)

# ============================================================================
# SIDEBAR
# ============================================================================

def render_sidebar():
    """Render the sidebar navigation"""
    with st.sidebar:
        # Snowflake logo and title
        st.markdown("""
        <div style="text-align: center; padding: 1rem 0 1.5rem 0;">
            <div style="font-size: 3rem; margin-bottom: 0.5rem;">❄️</div>
            <h2 style="color: white; font-size: 1.3rem; margin: 0; font-weight: 700;">Data Contracts</h2>
            <p style="color: #29B5E8; font-size: 0.85rem; margin: 0.25rem 0 0 0;">Enterprise Demo</p>
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
        
        # Footer
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
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🤖 Snowflake Cortex</h1>
        <p>Ask questions about your data in natural language</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Model selector
    col1, col2 = st.columns([3, 1])
    with col1:
        models = get_semantic_models()
        selected_model = st.selectbox(
            "Select Semantic Model",
            models,
            help="Choose which semantic model to query"
        )
    with col2:
        st.write("")  # Spacing
        if st.button("🔄 Refresh", use_container_width=True):
            st.cache_data.clear()
    
    st.divider()
    
    # Initialize chat history
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    # Display chat history
    for message in st.session_state.messages:
        role_class = "user" if message["role"] == "user" else "assistant"
        icon = "👤" if role_class == "user" else "🤖"
        st.markdown(f"""
        <div class="chat-message {role_class}">
            <strong>{icon} {'You' if role_class == 'user' else 'Cortex'}</strong>
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
            "product_analytics_model.yaml": [
                "Which products have the highest profit margin?",
                "Show me inventory levels by product type",
                "What are our top 10 selling products?",
                "Which product categories need restocking?"
            ],
            "supplier_analytics_model.yaml": [
                "Which suppliers have the best on-time delivery?",
                "Show me supplier performance by region",
                "What is the average lead time by supplier?",
                "Which suppliers have quality issues?"
            ],
            "governance_analytics_model.yaml": [
                "Which contracts have SLA violations?",
                "What is our overall data quality score?",
                "Show me contracts with the most consumers",
                "What percentage of columns have governance tags?"
            ]
        }
        
        questions = sample_questions.get(selected_model, [
            "What are the key metrics?",
            "Show me a summary of the data",
            "What trends do you see?",
            "What are the top performing items?"
        ])
        
        cols = st.columns(2)
        for i, q in enumerate(questions):
            with cols[i % 2]:
                if st.button(f"💬 {q}", key=f"sample_{i}", use_container_width=True):
                    # Process immediately
                    process_and_display_question(q, selected_model)
    
    # Chat input
    st.divider()
    
    # Simple text input with button (no form for better compatibility)
    col1, col2 = st.columns([5, 1])
    with col1:
        user_question = st.text_input(
            "Question",
            placeholder="Ask a question about your data...",
            label_visibility="collapsed",
            key="main_question_input"
        )
    with col2:
        ask_clicked = st.button("🚀 Ask", use_container_width=True, key="ask_button")
    
    if ask_clicked and user_question:
        process_and_display_question(user_question, selected_model)
    
    # Clear chat button
    if st.session_state.messages:
        if st.button("🗑️ Clear Chat", key="clear_chat"):
            st.session_state.messages = []

def process_and_display_question(question: str, model: str):
    """Process a user question and display results immediately"""
    # Add user message to history
    st.session_state.messages.append({"role": "user", "content": question})
    
    # Show spinner and get response
    with st.spinner("🤔 Thinking..."):
        response_text, sql_query, result_df = run_cortex_analyst(question, model)
    
    # Build response content
    content = response_text
    if sql_query:
        content += f"\n\n**Generated SQL:**\n```sql\n{sql_query}\n```"
    
    # Store response in history
    st.session_state.messages.append({
        "role": "assistant", 
        "content": content,
        "df": result_df
    })
    
    # Display the response immediately
    st.markdown("---")
    st.markdown("### 🤖 Response")
    st.markdown(content)
    
    if result_df is not None and not result_df.empty:
        st.markdown("**Results:**")
        st.dataframe(result_df, use_container_width=True, hide_index=True)

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
    
    # ─────────────────────────────────────────────────────────────────────────
    # Charts Row
    # ─────────────────────────────────────────────────────────────────────────
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📈 SLA Compliance Trend")
        if not sla.empty and 'HOUR' in sla.columns and 'COMPLIANCE_RATE' in sla.columns:
            chart_data = sla[['HOUR', 'COMPLIANCE_RATE']].copy()
            chart_data = chart_data.sort_values('HOUR')
            st.line_chart(chart_data.set_index('HOUR'))
        else:
            st.info("📊 No SLA trend data available yet. Run validation procedures to generate metrics.")
    
    with col2:
        st.markdown("### 🏷️ Governance Tag Coverage")
        if not tags.empty and 'TAG_NAME' in tags.columns and 'COVERAGE_PCT' in tags.columns:
            chart_data = tags[['TAG_NAME', 'COVERAGE_PCT']].copy()
            st.bar_chart(chart_data.set_index('TAG_NAME'))
        else:
            st.info("🏷️ No tag coverage data available yet. Register contracts to see coverage.")
    
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
        
        if display_cols:
            st.dataframe(
                display_df[display_cols],
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("📋 Contract health data structure differs from expected. Check observability views.")
    else:
        st.info("📋 No contract health data available yet. Register contracts and run validations.")
    
    st.divider()
    
    # ─────────────────────────────────────────────────────────────────────────
    # Active Alerts
    # ─────────────────────────────────────────────────────────────────────────
    
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
                        st.dataframe(consumers, use_container_width=True, hide_index=True)
                    else:
                        st.info("No registered consumers for this contract")
                except:
                    st.info("Unable to load consumer data")
            
            st.divider()
            
            # Quality Rules
            st.markdown("### ✅ Quality Rules")
            try:
                rules = session.sql(f"""
                    SELECT RULE_ID, RULE_NAME, RULE_TYPE, SEVERITY, ENABLED
                    FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES
                    WHERE CONTRACT_ID = '{selected_contract}'
                """).to_pandas()
                
                if not rules.empty:
                    st.dataframe(rules, use_container_width=True, hide_index=True)
                else:
                    st.info("No quality rules defined for this contract")
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
        
        - **Cortex Analyst** — Natural language to SQL
        - **LLM Functions** — COMPLETE, SUMMARIZE, TRANSLATE
        - **ML Functions** — FORECAST, ANOMALY_DETECTION
        - **Semantic Models** — YAML definitions for each domain
        """)
        
        st.markdown("""
        ### 📚 Resources
        
        - [Snowflake Horizon](https://www.snowflake.com/horizon/)
        - [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
        - [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
        - [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
        """)
    
    st.divider()
    
    st.markdown("""
    ### 🎯 Architecture Principle
    
    > *"AI, governance, and automation cannot scale unless business intent is explicit, portable, and enforceable by the data platform itself."*
    
    **Dependency Chain:** `People → Data → Governance → Automation`
    
    Each layer inherits stability from the layer before it.
    """)
    
    st.markdown("---")
    st.markdown("*Built with ❄️ Streamlit in Snowflake*")

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
