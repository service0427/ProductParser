const { Client } = require('pg');

async function createPPSchema() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb_pp',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ productparser_db 연결 성공!\n');

    // 새로운 스키마 생성
    console.log('ProductParser 전용 스키마 생성 중...');
    
    try {
      await client.query('CREATE SCHEMA IF NOT EXISTS pp AUTHORIZATION techb_pp');
      console.log('✅ pp 스키마 생성 성공!\n');
      
      // search_path 설정
      await client.query('SET search_path TO pp, public');
      console.log('✅ search_path 설정: pp, public\n');
      
      // 스키마 권한 확인
      const schemaInfo = await client.query(`
        SELECT 
          nspname as schema_name,
          pg_get_userbyid(nspowner) as owner,
          has_schema_privilege(current_user, nspname, 'CREATE') as can_create,
          has_schema_privilege(current_user, nspname, 'USAGE') as can_usage
        FROM pg_namespace
        WHERE nspname = 'pp'
      `);
      
      console.log('pp 스키마 정보:');
      const schema = schemaInfo.rows[0];
      console.log(`  소유자: ${schema.owner}`);
      console.log(`  CREATE 권한: ${schema.can_create}`);
      console.log(`  USAGE 권한: ${schema.can_usage}`);
      
      console.log('\n✅ 이제 pp 스키마에 테이블을 생성할 수 있습니다.');
      console.log('예: CREATE TABLE pp.agents (...);');
      
    } catch (schemaError) {
      if (schemaError.code === '42P06') {
        console.log('ℹ️  pp 스키마가 이미 존재합니다.');
        
        // 기존 테이블 확인
        const existingTables = await client.query(`
          SELECT tablename 
          FROM pg_tables 
          WHERE schemaname = 'pp'
          ORDER BY tablename
        `);
        
        console.log('\npp 스키마의 기존 테이블:');
        if (existingTables.rows.length === 0) {
          console.log('  (없음)');
        } else {
          existingTables.rows.forEach(row => {
            console.log(`  - ${row.tablename}`);
          });
        }
      } else {
        throw schemaError;
      }
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

createPPSchema();