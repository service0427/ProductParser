const { Client } = require('pg');

async function checkPermissions() {
  const client = new Client({
    host: 'mkt.techb.kr',
    user: 'techb',
    password: 'Tech1324!',
    database: 'productparser_db',
    port: 5432
  });

  try {
    await client.connect();
    console.log('✅ 데이터베이스 연결 성공!\n');

    // 현재 사용자 확인
    const userResult = await client.query('SELECT current_user, session_user');
    console.log('현재 사용자:', userResult.rows[0]);

    // 데이터베이스 소유자 확인
    const dbOwnerResult = await client.query(`
      SELECT d.datname, r.rolname as owner
      FROM pg_database d
      JOIN pg_roles r ON d.datdba = r.oid
      WHERE d.datname = current_database()
    `);
    console.log('\n데이터베이스 정보:', dbOwnerResult.rows[0]);

    // 스키마 권한 확인
    const schemaPermResult = await client.query(`
      SELECT 
        nspname as schema_name,
        nspowner::regrole as owner,
        has_schema_privilege(current_user, nspname, 'CREATE') as can_create,
        has_schema_privilege(current_user, nspname, 'USAGE') as can_use
      FROM pg_namespace
      WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      ORDER BY nspname
    `);
    console.log('\n스키마 권한:');
    schemaPermResult.rows.forEach(row => {
      console.log(`  - ${row.schema_name}: 소유자=${row.owner}, CREATE=${row.can_create}, USAGE=${row.can_use}`);
    });

    // 테이블 생성 권한 확인
    const createPrivResult = await client.query(`
      SELECT has_database_privilege(current_user, current_database(), 'CREATE') as can_create_in_db
    `);
    console.log('\n데이터베이스에 객체 생성 권한:', createPrivResult.rows[0].can_create_in_db);

    // 역할 멤버십 확인
    const roleResult = await client.query(`
      SELECT 
        r.rolname,
        r.rolsuper,
        r.rolinherit,
        r.rolcreaterole,
        r.rolcreatedb,
        r.rolcanlogin,
        r.rolreplication
      FROM pg_roles r
      WHERE r.rolname = current_user
    `);
    console.log('\n사용자 역할 정보:', roleResult.rows[0]);

    // 사용 가능한 스키마 목록
    const availableSchemas = await client.query(`
      SELECT DISTINCT schemaname 
      FROM pg_tables 
      WHERE has_table_privilege(current_user, schemaname||'.'||tablename, 'SELECT')
      UNION
      SELECT 'public'
      ORDER BY 1
    `);
    console.log('\n접근 가능한 스키마:');
    availableSchemas.rows.forEach(row => {
      console.log(`  - ${row.schemaname}`);
    });

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
  } finally {
    await client.end();
    console.log('\n연결 종료됨');
  }
}

// 실행
checkPermissions();