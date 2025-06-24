const { Client } = require('pg');

async function createPPTables() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb_pp',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ productparser_db 연결 성공! (사용자: techb_pp)\n');

    console.log('pp 스키마에 ProductParser 테이블 생성 시작...\n');

    // 1. agents 테이블
    console.log('1. agents 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.agents (
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
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(pc_id, port)
      )
    `);
    console.log('   ✅ agents 테이블 생성 완료');

    // 2. actions 테이블 (액션 정의)
    console.log('\n2. actions 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.actions (
        action_name VARCHAR(50) PRIMARY KEY,
        version VARCHAR(20) NOT NULL,
        description TEXT,
        code TEXT NOT NULL,
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('   ✅ actions 테이블 생성 완료');

    // 3. tasks 테이블 (작업 요청)
    console.log('\n3. tasks 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.tasks (
        task_id VARCHAR(100) PRIMARY KEY,
        action_name VARCHAR(50) REFERENCES pp.actions(action_name),
        params JSONB DEFAULT '{}',
        status VARCHAR(20) DEFAULT 'pending',
        priority INTEGER DEFAULT 0,
        agent_count INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        started_at TIMESTAMP,
        completed_at TIMESTAMP
      )
    `);
    console.log('   ✅ tasks 테이블 생성 완료');

    // 4. task_assignments 테이블 (작업 할당)
    console.log('\n4. task_assignments 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.task_assignments (
        assignment_id SERIAL PRIMARY KEY,
        task_id VARCHAR(100) REFERENCES pp.tasks(task_id),
        agent_id VARCHAR(50) REFERENCES pp.agents(agent_id),
        status VARCHAR(20) DEFAULT 'assigned',
        assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        started_at TIMESTAMP,
        completed_at TIMESTAMP
      )
    `);
    console.log('   ✅ task_assignments 테이블 생성 완료');

    // 5. task_results 테이블 (작업 결과)
    console.log('\n5. task_results 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.task_results (
        result_id SERIAL PRIMARY KEY,
        task_id VARCHAR(100) REFERENCES pp.tasks(task_id),
        agent_id VARCHAR(50) REFERENCES pp.agents(agent_id),
        assignment_id INTEGER REFERENCES pp.task_assignments(assignment_id),
        success BOOLEAN NOT NULL,
        data JSONB,
        error TEXT,
        execution_time INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('   ✅ task_results 테이블 생성 완료');

    // 6. finance_data 테이블 (네이버 금융 데이터)
    console.log('\n6. finance_data 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.finance_data (
        id SERIAL PRIMARY KEY,
        task_id VARCHAR(100) REFERENCES pp.tasks(task_id),
        agent_id VARCHAR(50) REFERENCES pp.agents(agent_id),
        market_data JSONB,
        exchange_data JSONB,
        commodity_data JSONB,
        collected_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('   ✅ finance_data 테이블 생성 완료');

    // 7. agent_performance 테이블 (성능 통계)
    console.log('\n7. agent_performance 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pp.agent_performance (
        agent_id VARCHAR(50) REFERENCES pp.agents(agent_id),
        date DATE,
        total_tasks INTEGER DEFAULT 0,
        successful_tasks INTEGER DEFAULT 0,
        failed_tasks INTEGER DEFAULT 0,
        avg_execution_time INTEGER,
        uptime_seconds INTEGER DEFAULT 0,
        PRIMARY KEY (agent_id, date)
      )
    `);
    console.log('   ✅ agent_performance 테이블 생성 완료');

    // 인덱스 생성
    console.log('\n인덱스 생성 중...');
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_agents_status ON pp.agents(status);
      CREATE INDEX IF NOT EXISTS idx_agents_heartbeat ON pp.agents(last_heartbeat);
      CREATE INDEX IF NOT EXISTS idx_tasks_status ON pp.tasks(status);
      CREATE INDEX IF NOT EXISTS idx_tasks_created ON pp.tasks(created_at);
      CREATE INDEX IF NOT EXISTS idx_assignments_status ON pp.task_assignments(status);
      CREATE INDEX IF NOT EXISTS idx_results_task ON pp.task_results(task_id);
      CREATE INDEX IF NOT EXISTS idx_results_agent ON pp.task_results(agent_id);
      CREATE INDEX IF NOT EXISTS idx_finance_collected ON pp.finance_data(collected_at);
    `);
    console.log('   ✅ 인덱스 생성 완료');

    // 뷰 생성
    console.log('\n뷰 생성 중...');
    
    // 활성 에이전트 뷰
    await client.query(`
      CREATE OR REPLACE VIEW pp.active_agents AS
      SELECT 
        agent_id,
        pc_id,
        port,
        status,
        platform,
        version,
        capabilities,
        last_heartbeat,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_heartbeat)) as seconds_since_heartbeat
      FROM pp.agents
      WHERE status = 'active'
        AND last_heartbeat > CURRENT_TIMESTAMP - INTERVAL '90 seconds'
    `);
    
    // 작업 상태 요약 뷰
    await client.query(`
      CREATE OR REPLACE VIEW pp.task_summary AS
      SELECT 
        t.task_id,
        t.action_name,
        t.status,
        t.created_at,
        t.completed_at,
        COUNT(DISTINCT ta.agent_id) as assigned_agents,
        COUNT(DISTINCT CASE WHEN tr.success THEN tr.agent_id END) as successful_agents,
        AVG(tr.execution_time) as avg_execution_time
      FROM pp.tasks t
      LEFT JOIN pp.task_assignments ta ON t.task_id = ta.task_id
      LEFT JOIN pp.task_results tr ON t.task_id = tr.task_id
      GROUP BY t.task_id, t.action_name, t.status, t.created_at, t.completed_at
    `);
    
    console.log('   ✅ 뷰 생성 완료');

    // 트리거 함수 생성 (updated_at 자동 업데이트)
    console.log('\n트리거 함수 생성 중...');
    await client.query(`
      CREATE OR REPLACE FUNCTION pp.update_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);

    // 트리거 생성
    await client.query(`
      CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON pp.agents
        FOR EACH ROW EXECUTE FUNCTION pp.update_updated_at();
      
      CREATE TRIGGER update_actions_updated_at BEFORE UPDATE ON pp.actions
        FOR EACH ROW EXECUTE FUNCTION pp.update_updated_at();
    `);
    console.log('   ✅ 트리거 생성 완료');

    // 생성된 테이블 확인
    const tables = await client.query(`
      SELECT 
        table_name,
        pg_size_pretty(pg_total_relation_size('pp.'||table_name)) as size
      FROM information_schema.tables 
      WHERE table_schema = 'pp' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);
    
    console.log('\n생성된 테이블:');
    tables.rows.forEach(row => {
      console.log(`  - pp.${row.table_name} (${row.size})`);
    });

    // 샘플 데이터 삽입
    console.log('\n샘플 데이터 삽입 중...');
    
    // 네이버 금융 액션 등록
    await client.query(`
      INSERT INTO pp.actions (action_name, version, description, code, metadata)
      VALUES (
        'naver-finance',
        '1.0.0',
        '네이버 금융에서 코스피, 코스닥, 환율, 금값 데이터 수집',
        '// 실제 코드는 파일에서 로드',
        '{"features": ["screenshot", "detailed"], "timeout": 30000}'::jsonb
      )
      ON CONFLICT (action_name) DO UPDATE
      SET version = EXCLUDED.version,
          updated_at = CURRENT_TIMESTAMP
    `);
    console.log('   ✅ naver-finance 액션 등록 완료');

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    console.error(error);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
console.log('========================================');
console.log('  pp 스키마에 ProductParser 테이블 생성');
console.log('========================================\n');

createPPTables();