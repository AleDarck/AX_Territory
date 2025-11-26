let currentState = null;
let countdownInterval = null;
let currentTerritoryData = null;
let captureTimerInterval = null;

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'showUI':
            showUI(data.data);
            break;
        case 'hideUI':
            hideUI();
            break;
        case 'updateProgress':
            updateProgress(data.territoryId, data.progress, data.gangCounts, data.elapsed, data.totalTime);
            break;
        case 'captureFinished':
            captureFinished(data.territoryId, data.winner);
            break;
    }
});

// Configuración de colores de bandas (RGB de config.lua)
const gangColors = {
    'ballas': 'rgb(145, 0, 200)',
    'vagos': 'rgb(255, 215, 0)',
    'families': 'rgb(0, 200, 0)',
    'marabunta': 'rgb(0, 180, 255)',
    'cartel': 'rgb(0, 40, 80)',
    'triad': 'rgb(200, 0, 0)'
};

function showUI(data) {
    currentTerritoryData = data;
    
    // Ocultar todos los estados
    document.getElementById('free-state').classList.add('hidden');
    document.getElementById('dispute-state').classList.add('hidden');
    document.getElementById('captured-state').classList.add('hidden');
    
    // Mostrar el contenedor principal
    document.getElementById('territory-ui').classList.remove('hidden');
    
    // Actualizar hint de tecla
    const hints = document.querySelectorAll('.hint-text');
    hints.forEach(hint => {
        hint.textContent = `Presiona ${data.hideKey} para ocultar/mostrar`;
    });
    
    // Mostrar el estado correspondiente
    if (data.status === 'free') {
        showFreeState(data);
    } else if (data.status === 'dispute') {
        showDisputeState(data);
    } else if (data.status === 'captured') {
        showCapturedState(data);
    }
}

function showFreeState(data) {
    const container = document.getElementById('free-state');
    container.querySelector('.territory-name').textContent = data.name;
    
    const instructionsText = container.querySelector('.info-text');
    instructionsText.textContent = `Usa /${data.captureCommand} para comenzar a capturar este territorio`;
    
    container.classList.remove('hidden');
    currentState = 'free';
}

function showDisputeState(data) {
    const container = document.getElementById('dispute-state');
    container.classList.remove('hidden');
    currentState = 'dispute';
    
    // El progreso se actualizará mediante updateProgress
}

function showCapturedState(data) {
    const container = document.getElementById('captured-state');
    container.querySelector('.territory-name').textContent = data.name;
    
    const statusBadge = document.getElementById('status-badge-captured');
    const attackInfo = document.getElementById('attack-info');
    const countdownSection = document.getElementById('countdown-section');
    
    if (data.cooldownRemaining > 0) {
        // En cooldown
        statusBadge.innerHTML = `
            <i class="fas fa-hourglass-half"></i>
            <span>EN COOLDOWN</span>
        `;
        statusBadge.style.borderColor = '#ff9800';
        
        document.getElementById('owner-name').textContent = data.ownerName;
        
        countdownSection.classList.remove('hidden');
        attackInfo.classList.add('hidden');
        
        startCountdown(data.cooldownRemaining);
    } else {
        // Disponible para atacar
        statusBadge.innerHTML = `
            <i class="fas fa-unlock"></i>
            <span>DISPONIBLE</span>
        `;
        statusBadge.style.borderColor = '#4caf50';
        
        document.getElementById('owner-name').textContent = data.ownerName;
        
        countdownSection.classList.add('hidden');
        attackInfo.classList.remove('hidden');
        
        const instructionsText = attackInfo.querySelector('.info-text');
        instructionsText.textContent = `Usa /${data.attackCommand} para atacar este territorio. TODAS LAS BANDAS SERÁN ALERTADAS`;
    }
    
    container.classList.remove('hidden');
    currentState = 'captured';
}

function updateProgress(territoryId, progress, gangCounts, elapsed, totalTime) {
    if (currentState !== 'dispute') return;
    
    // Actualizar timer
    const minutes = Math.floor(elapsed / 60);
    const seconds = elapsed % 60;
    document.getElementById('capture-timer').textContent = `${minutes}:${String(seconds).padStart(2, '0')}`;
    
    // Actualizar barra de progreso del tiempo
    const timeProgress = (elapsed / totalTime) * 100;
    document.getElementById('timer-progress-fill').style.width = `${timeProgress}%`;
    
    const container = document.getElementById('gangs-progress');
    container.innerHTML = '';
    
    // Ordenar bandas por progreso descendente
    const sortedGangs = Object.entries(progress).sort((a, b) => b[1] - a[1]);
    
    // Crear items para cada banda
    for (let [gang, percentage] of sortedGangs) {
        const playerCount = gangCounts[gang] || 0;
        const gangColor = gangColors[gang] || 'rgb(255, 255, 255)';
        
        const gangItem = document.createElement('div');
        gangItem.className = 'gang-item';
        
        gangItem.innerHTML = `
            <div class="gang-header">
                <div class="gang-name-box">
                    <div class="gang-color-indicator" style="background-color: ${gangColor};"></div>
                    <span class="gang-name">${gang.toUpperCase()}</span>
                </div>
                <span class="gang-percentage">${Math.floor(percentage)}%</span>
            </div>
            <div class="gang-stats">
                <span><i class="fas fa-users"></i> ${playerCount} jugador${playerCount !== 1 ? 'es' : ''}</span>
                <span><i class="fas fa-chart-line"></i> ${Math.floor(percentage)}/100</span>
            </div>
            <div class="progress-container">
                <div class="progress-fill" style="width: ${Math.min(100, percentage)}%; background: linear-gradient(90deg, ${gangColor}, ${adjustColorBrightness(gangColor, 40)});"></div>
            </div>
        `;
        
        container.appendChild(gangItem);
    }
    
    // Si no hay bandas capturando
    if (sortedGangs.length === 0) {
        container.innerHTML = `
            <div style="text-align: center; padding: 30px; color: #666;">
                <i class="fas fa-users-slash" style="font-size: 40px; margin-bottom: 15px; display: block;"></i>
                <p style="font-size: 14px;">No hay bandas capturando actualmente</p>
            </div>
        `;
    }
}

function adjustColorBrightness(color, percent) {
    const num = parseInt(color.replace("rgb(", "").replace(")", "").split(',').map(x => parseInt(x.trim())));
    const amt = Math.round(2.55 * percent);
    const R = Math.min(255, Math.max(0, parseInt(color.split(',')[0].replace('rgb(', '')) + amt));
    const G = Math.min(255, Math.max(0, parseInt(color.split(',')[1]) + amt));
    const B = Math.min(255, Math.max(0, parseInt(color.split(',')[2].replace(')', '')) + amt));
    return `rgb(${R}, ${G}, ${B})`;
}

function captureFinished(territoryId, winner) {
    // El UI se actualizará automáticamente desde el cliente
}

function startCountdown(seconds) {
    if (countdownInterval) {
        clearInterval(countdownInterval);
    }
    
    let remaining = seconds;
    updateCountdownDisplay(remaining);
    
    countdownInterval = setInterval(() => {
        remaining--;
        
        if (remaining <= 0) {
            clearInterval(countdownInterval);
            countdownInterval = null;
            
            // Cambiar a disponible
            if (currentTerritoryData) {
                currentTerritoryData.cooldownRemaining = 0;
                showCapturedState(currentTerritoryData);
            }
            return;
        }
        
        updateCountdownDisplay(remaining);
    }, 1000);
}

function updateCountdownDisplay(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    const timerElement = document.getElementById('countdown-timer');
    timerElement.innerHTML = `
        <div class="time-box">
            <span class="time-number">${String(hours).padStart(2, '0')}</span>
            <span class="time-unit">H</span>
            <span class="time-separator">:</span>
            <span class="time-number">${String(minutes).padStart(2, '0')}</span>
            <span class="time-unit">M</span>
            <span class="time-separator">:</span>
            <span class="time-number">${String(secs).padStart(2, '0')}</span>
            <span class="time-unit">S</span>
        </div>
    `;
}

function hideUI() {
    if (countdownInterval) {
        clearInterval(countdownInterval);
        countdownInterval = null;
    }
    
    if (captureTimerInterval) {
        clearInterval(captureTimerInterval);
        captureTimerInterval = null;
    }
    
    // Agregar animación de cierre
    const containers = document.querySelectorAll('.territory-container');
    containers.forEach(container => {
        if (!container.classList.contains('hidden')) {
            container.classList.add('closing');
        }
    });
    
    setTimeout(() => {
        document.getElementById('territory-ui').classList.add('hidden');
        containers.forEach(container => {
            container.classList.remove('closing');
            container.classList.add('hidden');
        });
        currentState = null;
    }, 300);
}