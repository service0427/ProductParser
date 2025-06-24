const { Client } = require('pg');

async function createTables() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ productparser_db 연결 성공!\n');

    // 기존 테이블 확인
    const existingTables = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
    `);
    
    console.log('기존 테이블:');
    if (existingTables.rows.length === 0) {
      console.log('  (없음)');
    } else {
      existingTables.rows.forEach(row => {
        console.log(`  - ${row.table_name}`);
      });
    }
    console.log('');

    // 1. agents 테이블 생성
    console.log('1. agents 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS agents (
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
      )
    `);
    console.log('   ✅ agents 테이블 생성 완료');

    // 2. parsing_tasks 테이블 생성
    console.log('\n2. parsing_tasks 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS parsing_tasks (
        task_id VARCHAR(100) PRIMARY KEY,
        action_name VARCHAR(50) NOT NULL,
        params JSONB DEFAULT '{}',
        status VARCHAR(20) DEFAULT 'pending',
        assigned_agents TEXT[],
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        started_at TIMESTAMP,
        completed_at TIMESTAMP
      )
    `);
    console.log('   ✅ parsing_tasks 테이블 생성 완료');

    // 3. task_results 테이블 생성
    console.log('\n3. task_results 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS task_results (
        result_id SERIAL PRIMARY KEY,
        task_id VARCHAR(100) REFERENCES parsing_tasks(task_id),
        agent_id VARCHAR(50) REFERENCES agents(agent_id),
        success BOOLEAN NOT NULL,
        data JSONB,
        error TEXT,
        execution_time INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('   ✅ task_results 테이블 생성 완료');

    // 4. action_versions 테이블 생성
    console.log('\n4. action_versions 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS action_versions (
        action_name VARCHAR(50),
        version VARCHAR(20),
        code TEXT NOT NULL,
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (action_name, version)
      )
    `);
    console.log('   ✅ action_versions 테이블 생성 완료');

    // 5. agent_performance 테이블 생성
    console.log('\n5. agent_performance 테이블 생성 중...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS agent_performance (
        agent_id VARCHAR(50) REFERENCES agents(agent_id),
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
      CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);
      CREATE INDEX IF NOT EXISTS idx_agents_last_heartbeat ON agents(last_heartbeat);
      CREATE INDEX IF NOT EXISTS idx_tasks_status ON parsing_tasks(status);
      CREATE INDEX IF NOT EXISTS idx_tasks_created ON parsing_tasks(created_at);
      CREATE INDEX IF NOT EXISTS idx_results_task ON task_results(task_id);
      CREATE INDEX IF NOT EXISTS idx_results_agent ON task_results(agent_id);
    `);
    console.log('   ✅ 인덱스 생성 완료');

    // 생성된 테이블 확인
    const tables = await client.query(`
      SELECT table_name, 
             pg_size_pretty(pg_total_relation_size(table_name::regclass)) as size
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);
    
    console.log('\n생성된 테이블:');
    tables.rows.forEach(row => {
      console.log(`  - ${row.table_name} (${row.size})`);
    });

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    console.error(error);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
createTables();