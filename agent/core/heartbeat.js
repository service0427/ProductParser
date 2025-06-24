const axios = require('axios');
const os = require('os');

class HeartbeatManager {
  constructor() {
    this.interval = null;
    this.isRunning = false;
    this.lastHeartbeat = null;
    this.failureCount = 0;
  }

  async sendHeartbeat(config) {
    try {
      const systemInfo = this.getSystemInfo();
      
      const data = {
        agentId: config.agentId,
        pcId: config.pcId,
        port: config.port,
        timestamp: new Date().toISOString(),
        status: 'active',
        system: systemInfo,
        platform: process.platform,
        uptime: process.uptime(),
        failureCount: this.failureCount
      };
      
      const response = await axios.post(
        `${config.hubUrl}/api/agents/heartbeat`,
        data,
        { timeout: 5000 }
      );
      
      this.lastHeartbeat = new Date();
      this.failureCount = 0;
      
      console.log(`[${new Date().toLocaleTimeString()}] Heartbeat sent successfully`);
      
      return response.data;
      
    } catch (error) {
      this.failureCount++;
      console.error(`[${new Date().toLocaleTimeString()}] Heartbeat failed:`, error.message);
      
      // 10번 연속 실패 시 경고
      if (this.failureCount >= 10) {
        console.error('WARNING: Unable to connect to hub for 10 consecutive attempts');
      }
      
      throw error;
    }
  }
  
  getSystemInfo() {
    const cpus = os.cpus();
    const totalMemory = os.totalmem();
    const freeMemory = os.freemem();
    const usedMemory = totalMemory - freeMemory;
    
    return {
      cpu: {
        model: cpus[0].model,
        cores: cpus.length,
        usage: this.getCPUUsage(cpus)
      },
      memory: {
        total: totalMemory,
        free: freeMemory,
        used: usedMemory,
        usagePercent: Math.round((usedMemory / totalMemory) * 100)
      },
      platform: {
        type: os.type(),
        release: os.release(),
        arch: os.arch()
      }
    };
  }
  
  getCPUUsage(cpus) {
    // 간단한 CPU 사용률 계산
    let totalIdle = 0;
    let totalTick = 0;
    
    cpus.forEach(cpu => {
      for (type in cpu.times) {
        totalTick += cpu.times[type];
      }
      totalIdle += cpu.times.idle;
    });
    
    const idle = totalIdle / cpus.length;
    const total = totalTick / cpus.length;
    const usage = 100 - ~~(100 * idle / total);
    
    return usage;
  }
  
  start(config) {
    if (this.isRunning) {
      console.log('Heartbeat already running');
      return;
    }
    
    console.log(`Starting heartbeat with interval: ${config.heartbeatInterval}ms`);
    
    // 즉시 한번 전송
    this.sendHeartbeat(config).catch(err => {
      console.error('Initial heartbeat failed:', err.message);
    });
    
    // 주기적 전송
    this.interval = setInterval(() => {
      this.sendHeartbeat(config).catch(err => {
        // 에러는 이미 sendHeartbeat에서 로깅됨
      });
    }, config.heartbeatInterval);
    
    this.isRunning = true;
  }
  
  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
      this.isRunning = false;
      console.log('Heartbeat stopped');
    }
  }
  
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastHeartbeat: this.lastHeartbeat,
      failureCount: this.failureCount
    };
  }
}

module.exports = new HeartbeatManager();