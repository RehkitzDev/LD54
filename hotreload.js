const http = require('http');
const fs = require('fs');
const net = require('net');
const path = require('path');
const { exec } = require('child_process');

// const optimize = "-O";
// debug
const optimize = "-g";
const wasm_opt_path = 'c:/odin/bin/wasm-opt.exe';
const asyncify_args = '--pass-arg=asyncify-imports@env.frame,audio._load_sound';

const ws_connections = [];

let last_event_type = '';
fs.watch('./bin', async (eventType, filename) => {

    if (filename.includes('.wasm.o')) {
        if (eventType == 'rename' && last_event_type == 'change') {

            console.log('Optimizing...');

            let file_name = filename.replace('.o', '');

            let str = `${wasm_opt_path} ./bin/${file_name} ${optimize} --asyncify ${asyncify_args} -o ./bin/${file_name}`;

            console.log(str);

            // create exec promise
            await new Promise((resolve, reject) => {
                exec(str, (err, stdout, stderr) => {
                    if (err) {
                        console.log(err);
                        reject();
                        return;
                    }
                    console.log(stdout);
                    resolve();
                });
            }).catch((err) => {
                ws_connections.forEach((socket) => {
                    if (err == undefined){
                        err = 'undefined error. reload';
                    }
                    sendWebSocketMessage(socket, Buffer.from(err));
                });
                return
            });

            console.log("finsihed wasm-opt. reload ws_connections");

            ws_connections.forEach((socket) => {
                sendWebSocketMessage(socket, Buffer.from('reload'));
            });
        }
        last_event_type = eventType;
    }
});

const server = http.createServer((req, res) => {
    // Get the file path from the URL
    const filePath = path.join(__dirname, req.url);

    // Check if the file exists
    fs.stat(filePath, (err, stats) => {
        if (err) {
            // Return a 404 error if the file doesn't exist
            res.statusCode = 404;
            res.end('File not found');
            return;
        }

        // Check if the requested path is a directory
        if (stats.isDirectory()) {
            // If it is a directory, redirect to the index.html file
            res.writeHead(302, {
                'Location': 'index.html'
            });
            res.end();
            return;
        }

        // Set the correct MIME type for the file
        const extname = path.extname(filePath);
        let contentType = 'text/html';
        switch (extname) {
            case '.js':
                contentType = 'text/javascript';
                break;
            case '.wasm':
                contentType = 'application/wasm';
                break;
            case '.css':
                contentType = 'text/css';
                break;
        }
        res.setHeader('Content-Type', contentType);

        const fileStream = fs.createReadStream(filePath);
        fileStream.pipe(res);
    });
});

const ws = net.createServer((socket) => {
    socket.on('data', (data) => {
        if (data.toString().includes('Upgrade: websocket')) {
            function calculateAcceptKey(key) {
                const MAGIC_STRING = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
                const concatenated = `${key}${MAGIC_STRING}`;
                const sha1 = require('crypto').createHash('sha1');
                sha1.update(concatenated);
                return sha1.digest('base64');
            }

            const key = data.toString().match(/Sec-WebSocket-Key:\s(.*)\r\n/)[1].trim();
            const acceptKey = calculateAcceptKey(key);
            let response = 'HTTP/1.1 101 Switching Protocols\r\n';
            response += 'Upgrade: websocket\r\n';
            response += 'Connection: Upgrade\r\n';
            response += `Sec-WebSocket-Accept: ${acceptKey}\r\n`;
            response += '\r\n';
            socket.write(response);

            ws_connections.push(socket);
            console.log('New connection');
        }
    });

    socket.on('message', (data) => {
        console.log(data);
    });

    socket.on('close', () => {
        const index = ws_connections.indexOf(socket);
        if (index > -1) {
            ws_connections.splice(index, 1);
        }
    });
    socket.on('error', () => {
        const index = ws_connections.indexOf(socket);
        if (index > -1) {
            ws_connections.splice(index, 1);
        }
    });
    socket.on('end', () => {
        const index = ws_connections.indexOf(socket);
        if (index > -1) {
            ws_connections.splice(index, 1);
        }
    });
});

function sendWebSocketMessage(socket, message, isBinary = false) {
    const opcode = isBinary ? 0b10000010 : 0b10000001;
    const length = message.length;
    let buffer;

    if (length <= 125) {
        buffer = Buffer.alloc(2 + length);
        buffer.writeUInt8(opcode, 0);
        buffer.writeUInt8(length, 1);
        message.copy(buffer, 2);
    } else if (length <= 65535) {
        buffer = Buffer.alloc(4 + length);
        buffer.writeUInt8(opcode, 0);
        buffer.writeUInt8(126, 1);
        buffer.writeUInt16BE(length, 2);
        message.copy(buffer, 4);
    } else {
        buffer = Buffer.alloc(10 + length);
        buffer.writeUInt8(opcode, 0);
        buffer.writeUInt8(127, 1);
        buffer.writeBigUInt64BE(BigInt(length), 2);
        message.copy(buffer, 10);
    }


    socket.write(buffer);
}

server.listen(8000, () => {
    console.log('Server running at http://localhost:8000/');
});
ws.listen(8001, () => {
    console.log('WebSocket server is running on port 8001');
});