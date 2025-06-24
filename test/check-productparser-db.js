const { Client } = require('pg');

async function checkProductParserDB() {
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

    // 데이터베이스 소유자 확인
    const ownerResult = await client.query(`
      SELECT 
        current_database() as database,
        current_user as current_user,
        pg_database.datname,
        pg_user.usename as owner
      FROM pg_database
      JOIN pg_user ON pg_database.datdba = pg_user.usesysid
      WHERE pg_database.datname = current_database()
    `);
    console.log('데이터베이스 정보:', ownerResult.rows[0]);

    // 스키마 목록 및 권한
    const schemaResult = await client.query(`
      SELECT 
        nspname as schema,
        pg_get_userbyid(nspowner) as owner,
        has_schema_privilege(current_user, nspname, 'CREATE') as can_create,
        has_schema_privilege(current_user, nspname, 'USAGE') as can_use
      FROM pg_namespace
      WHERE nspname NOT IN ('pg_catalog', 'information_schema')
      ORDER BY nspname
    `);
    console.log('\n스키마 권한:');
    schemaResult.rows.forEach(row => {
      console.log(`  ${row.schema}: 소유자=${row.owner}, CREATE=${row.can_create}, USAGE=${row.can_use}`);
    });

    // 권한 요청을 위한 SQL 명령어 생성
    console.log('\n필요한 권한을 얻기 위한 SQL (관리자가 실행해야 함):');
    console.log('-- productparser_db에서 실행');
    console.log('GRANT CREATE ON SCHEMA public TO techb;');
    console.log('GRANT ALL ON DATABASE productparser_db TO techb;');
    console.log('');
    console.log('-- 또는 별도 스키마 생성');
    console.log('CREATE SCHEMA IF NOT EXISTS parser AUTHORIZATION techb;');

  } catch (error) {
    console.error('❌ 오류:', error.message);
  } finally {
    await client.end();
  }
}

checkProductParserDB();