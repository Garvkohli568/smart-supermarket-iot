# Scalable Smart Supermarket IoT — runnable demonstration

This is a **local, single-host prototype** of Garv Kohli's SIT314 1.2D plan. The current simulator covers two stores and five sensor types: temperature, weight, humidity, door state and RFID item count. Node-RED validates and routes MQTT data; the Express API stores readings and alerts in MongoDB; a browser dashboard displays store-specific state. The integrated stack has **not** been verified on EC2, and horizontal or automatic scaling has not been measured.

## Windows quick start

Install Docker Desktop and Node.js 20+ on your computer. Open PowerShell in this folder:

```powershell
Copy-Item .env.example .env
```

Edit `.env` and set `INGEST_TOKEN` and `STAFF_PASSWORD` to different long random strings. Do not commit `.env`. Then run:

```powershell
docker compose up --build -d
npm install
npm test
npm run sim
```

Keep the simulator terminal open for around 20 seconds. Browse to `http://localhost:3000` for the dashboard and `http://localhost:1880` for the Node-RED flow. Node-RED is bound to localhost. The dashboard refreshes every three seconds. The simulator first publishes safe temperature and sufficient stock, then sends enough high readings to open a temperature alert and low stock to open a stock alert; it later returns to a safe temperature so that alert resolves. Press Ctrl+C to stop the simulator.

Check API endpoints from another PowerShell window:

```powershell
Invoke-RestMethod http://localhost:3000/health
Invoke-RestMethod http://localhost:3000/api/status
Invoke-RestMethod http://localhost:3000/api/readings
Invoke-RestMethod http://localhost:3000/api/alerts
docker compose logs --tail=50 nodered api
```

To demonstrate validation, publish an invalid MQTT message with a missing `eventId`:

```powershell
docker compose exec -T mqtt mosquitto_pub -h localhost -t supermarket/STORE01/refrigerator/FRIDGE01/temperature -m '{"storeId":"STORE01","deviceId":"FRIDGE01","sensorType":"temperature","value":7.2,"timestamp":"2026-09-25T00:00:00Z"}'
```

Node-RED's debug sidebar or logs show that the message was rejected. The actual event timestamp for normal messages comes from the simulator, not the example above. The API independently checks all required fields and value ranges.

## What the prototype implements

* Temperature threshold: above 5°C for **three consecutive readings**, then create/update one open HIGH_TEMPERATURE alert. A safe reading resolves it.
* Milk shelf: one unit weighs 2,100 g. `floor(weight / 2100)` estimates quantity. Below 10 units creates a LOW_STOCK alert; sufficient weight resolves it.
* A unique `eventId` index deduplicates stored readings. Multiple consumer instances and queue processing are **not** implemented. The demonstration uses one Node-RED and one API instance.
* The dashboard includes a demonstration staff login for alert acknowledgement. The API's ingest route requires a token. Keep the application behind restricted access during deployment; this is not a production identity system.

## Load test and evidence

Stop the normal simulator first. Take a baseline status screenshot. Run one workload at a time:

```powershell
npm run load -- 10 30
Invoke-RestMethod http://localhost:3000/api/status
npm run load -- 50 30
Invoke-RestMethod http://localhost:3000/api/status
npm run load -- 100 30
Invoke-RestMethod http://localhost:3000/api/status
```

The submitted local report recorded 300, 1,500 and 3,000 attempted publishes at 10/s, 50/s and 100/s. Its observed accepted count increased from 1,884 to 6,684 overall, with zero rejected and duplicate counts at the final observation. Separate 50/s and 100/s accepted deltas were inferred under the no-other-publisher/no-restart assumption, not independently captured. Those workloads used the earlier two-sensor version and were not repeated after the two-store expansion. The generator reports **attempted sends**, not latency, confirmed broker acknowledgements or AWS throughput. See `evidence/README.md`.

The service is deliberately a teaching prototype. If two API requests for the same device arrive concurrently, the simple read/update of the consecutive unsafe count can race. For trustworthy high-volume scaling, move ordered per-device decisions to a partitioned queue/worker and store processed events and state changes transactionally.

## EC2 demonstration

Create an Ubuntu EC2 instance with Docker Compose installed. Copy this project and a private `.env` onto the instance. In the instance's security group expose only **TCP 3000** to your own IP for the demo. MQTT and Node-RED are already bound to localhost in the Compose file, so do not open ports 1883 or 1880 publicly. To run the simulator on EC2, run `npm install` and `npm run sim` in a shell **on the instance**, or use an SSH tunnel. Run `docker compose up --build -d`, then browse to `http://EC2_PUBLIC_IP:3000` from your allowed IP. Check `docker compose ps` and `/api/status`. This proves deployment of the integrated prototype on one host; it does not prove horizontal or automatic scaling. Stop the instance when finished to avoid charges.

## Evidence list for submission

1. Architecture: the live Node-RED MQTT → validation → HTTP flow.
2. Input: simulator publishing both refrigerator and shelf topics.
3. Validation: Node-RED rejected message and API 400 response.
4. Processing: safe reading, three high readings, and a high-temperature alert; low stock and its alert.
5. Storage and output: MongoDB records plus dashboard and API responses.
6. Deployment: EC2 public dashboard, instance details, security group, and `docker compose ps`.
7. Testing: commands, input rate/duration, accepted-count differences, errors, timestamps, and limitations.

Do not commit `.env`, connection strings containing credentials, or screenshots with keys.
