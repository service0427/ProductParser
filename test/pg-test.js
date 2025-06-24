const { Client } = require('pg');

async function testConnection() {
  // 접속 정보
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb',
    password: 'Tech1324!',
    database: 'postgres', // 기본 데이터베이스로 시도
    port: 5432,
    ssl: false // SSL 설정은 필요시 변경
  });

  try {
    console.log('PostgreSQL 연결 시도 중...');
    console.log(`Host: ${client.host}`);
    console.log(`User: ${client.user}`);
    console.log(`Port: ${client.port}`);
    
    await client.connect();
    console.log('✅ PostgreSQL 연결 성공!');
    
    // 버전 확인
    const versionResult = await client.query('SELECT version()');
    console.log('\n데이터베이스 버전:');
    console.log(versionResult.rows[0].version);
    
    // 현재 데이터베이스 확인
    const dbResult = await client.query('SELECT current_database()');
    console.log('\n현재 데이터베이스:', dbResult.rows[0].current_database);
    
    // 데이터베이스 목록
    const dbListResult = await client.query(`
      SELECT datname 
      FROM pg_database 
      WHERE datistemplate = false
      ORDER BY datname
    `);
    console.log('\n사용 가능한 데이터베이스:');
    dbListResult.rows.forEach(row => {
      console.log(`  - ${row.datname}`);
    });
    
    // 스키마 목록
    const schemaResult = await client.query(`
      SELECT schema_name 
      FROM information_schema.schemata 
      WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
      ORDER BY schema_name
    `);
    console.log('\n스키마 목록:');
    schemaResult.rows.forEach(row => {
      console.log(`  - ${row.schema_name}`);
    });
    
    // public 스키마의 테이블 목록
    const tableResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);
    console.log('\npublic 스키마의 테이블:');
    if (tableResult.rows.length === 0) {
      console.log('  (테이블 없음)');
    } else {
      tableResult.rows.forEach(row => {
        console.log(`  - ${row.table_name}`);
      });
    }
    
  } catch (error) {
    console.error('❌ PostgreSQL 연결 실패:', error.message);
    console.error('에러 상세:', error);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 테스트 실행
testConnection();