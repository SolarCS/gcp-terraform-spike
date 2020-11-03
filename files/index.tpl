const {promisify} = require('util');
const redis = require('redis');

const REDISHOST = process.env.REDISHOST || "${redis-ip}";
const REDISPORT = process.env.REDISPORT || 6379;

const redisClient = redis.createClient(REDISPORT, REDISHOST);
redisClient.on('error', (err) => console.error('ERR:REDIS:', err));

const incrAsync = promisify(redisClient.incr).bind(redisClient);

exports.helloWorld = async (req, res) => {
  try {
    const response = await incrAsync('visits');
    console.log(response)
  } catch (err) {
    console.log(err);
  }
};