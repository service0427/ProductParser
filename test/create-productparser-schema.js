const { Client } = require('pg');

async function createProductParserSchema() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb',
    password: 'Tech1324!',
    database: 'mkt_rank_local',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ mkt_rank_local 데이터베이스 연결 성공!\n');

    console.log('ProductParser 스키마 및 테이블 생성 중...\n');

    // 1. agents 테이블 (이미 생성됨, 수정)
    console.log('1. agents 테이블 업데이트 중...');
    await client.query(`
      DROP TABLE IF EXISTS productparser.agents CASCADE;
      
      CREATE TABLE productparser.agents (
        agent_id VARCHAR(50) PRIMARY KEY,
        pc_id VARCHAR(20) NOT NULL,
        port INTEGER NOT NULL,
        status VARCHAR(20) DEFAULT 'offline',
        platform VARCHAR(20),
        version VARCHAR(20),
        capabilities JSONB DEFAULT '{}',
        system_info JSONB DEFAULT '{}',
        last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('   ✅ agents 테이블 생성 완료');

    // 2. parsing_tasks 테이블
    console.log('\n2. parsing_tasks 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS productparser.parsing_tasks (
        task_id VARCHAR(100) PRIMARY KEY,
        action_name VARCHAR(50) NOT NULL,
        params JSONB DEFAULT '{}',
        status VARCHAR(20) DEFAULT 'pending',
        assigned_agents TEXT[],
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        started_at TIMESTAMP,
        completed_at TIMESTAMP
      );
    `);
    console.log('   ✅ parsing_tasks 테이블 생성 완료');

    // 3. task_results 테이블
    console.log('\n3. task_results 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS productparser.task_results (
        result_id SERIAL PRIMARY KEY,
        task_id VARCHAR(100) REFERENCES productparser.parsing_tasks(task_id),
        agent_id VARCHAR(50) REFERENCES productparser.agents(agent_id),
        success BOOLEAN NOT NULL,
        data JSONB,
        error TEXT,
        execution_time INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('   ✅ task_results 테이블 생성 완료');

    // 4. action_versions 테이블
    console.log('\n4. action_versions 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS productparser.action_versions (
        action_name VARCHAR(50),
        version VARCHAR(20),
        code TEXT NOT NULL,
        description TEXT,
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (action_name, version)
      );
    `);
    console.log('   ✅ action_versions 테이블 생성 완료');

    // 5. agent_performance 테이블
    console.log('\n5. agent_performance 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS productparser.agent_performance (
        agent_id VARCHAR(50) REFERENCES productparser.agents(agent_id),
        date DATE,
        total_tasks INTEGER DEFAULT 0,
        successful_tasks INTEGER DEFAULT 0,
        failed_tasks INTEGER DEFAULT 0,
        avg_execution_time INTEGER,
        uptime_seconds INTEGER DEFAULT 0,
        PRIMARY KEY (agent_id, date)
      );
    `);
    console.log('   ✅ agent_performance 테이블 생성 완료');

    // 6. finance_data 테이블 (네이버 금융 데이터 저장용)
    console.log('\n6. finance_data 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS productparser.finance_data (
        id SERIAL PRIMARY KEY,
        task_id VARCHAR(100),
        agent_id VARCHAR(50),
        market_data JSONB,
        exchange_data JSONB,
        commodity_data JSONB,
        collected_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('   ✅ finance_data 테이블 생성 완료');

    // 인덱스 생성
    console.log('\n인덱스 생성 중...');
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_agents_status ON productparser.agents(status);
      CREATE INDEX IF NOT EXISTS idx_agents_heartbeat ON productparser.agents(last_heartbeat);
      CREATE INDEX IF NOT EXISTS idx_tasks_status ON productparser.parsing_tasks(status);
      CREATE INDEX IF NOT EXISTS idx_tasks_created ON productparser.parsing_tasks(created_at);
      CREATE INDEX IF NOT EXISTS idx_results_task ON productparser.task_results(task_id);
      CREATE INDEX IF NOT EXISTS idx_results_agent ON productparser.task_results(agent_id);
      CREATE INDEX IF NOT EXISTS idx_finance_collected ON productparser.finance_data(collected_at);
    `);
    console.log('   ✅ 인덱스 생성 완료');

    // 뷰 생성
    console.log('\n뷰 생성 중...');
    await client.query(`
      CREATE OR REPLACE VIEW productparser.active_agents AS
      SELECT 
        agent_id,
        pc_id,
        port,
        status,
        platform,
        last_heartbeat,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_heartbeat)) as seconds_since_heartbeat
      FROM productparser.agents
      WHERE status = 'active'
        AND last_heartbeat > CURRENT_TIMESTAMP - INTERVAL '90 seconds';
    `);
    console.log('   ✅ active_agents 뷰 생성 완료');

    // 생성된 테이블 확인
    const tables = await client.query(`
      SELECT 
        table_name,
        pg_size_pretty(pg_total_relation_size('productparser.'||table_name)) as size
      FROM information_schema.tables 
      WHERE table_schema = 'productparser' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    
    console.log('\n생성된 테이블:');
    tables.rows.forEach(row => {
      console.log(`  - ${row.table_name} (${row.size})`);
    });

    // 샘플 데이터 삽입
    console.log('\n샘플 에이전트 데이터 삽입...');
    await client.query(`
      INSERT INTO productparser.agents (agent_id, pc_id, port, status, platform, capabilities)
      VALUES 
        ('PC01-3001', 'PC01', 3001, 'active', 'win32', '{"actions": ["naver-finance"], "features": ["screenshot"]}'),
        ('PC01-3002', 'PC01', 3002, 'offline', 'win32', '{"actions": ["naver-finance"], "features": ["screenshot"]}')
      ON CONFLICT (agent_id) DO UPDATE
      SET status = EXCLUDED.status,
          last_heartbeat = CURRENT_TIMESTAMP;
    `);
    console.log('   ✅ 샘플 데이터 삽입 완료');

    // 활성 에이전트 확인
    const activeAgents = await client.query('SELECT * FROM productparser.active_agents');
    console.log('\n활성 에이전트:', activeAgents.rows);

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    console.error(error);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
createProductParserSchema();