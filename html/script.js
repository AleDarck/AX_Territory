let currentState = null;
let timerInterval = null;
let cooldownEnd = null;

$(document).ready(function() {
    
    window.addEventListener('message', function(event) {
        let data = event.data;
        
        switch(data.action) {
            case 'showUI':
                showUI(data);
                break;
                
            case 'hideUI':
                hideUI();
                break;
                
            case 'updateProgress':
                updateCaptureProgress(data.data);
                break;
        }
    });
});

function showUI(data) {
    const zoneData = data.data;
    const canCapture = data.canCapture;
    const isPolice = data.isPolice;
    const gangColors = data.gangColors;
    
    // Limpiar estados previos
    $('.territory-card').removeClass('active closing');
    
    // Determinar estado
    let state = 'free';
    
    if (zoneData.state === 'contested') {
        state = 'contested';
    } else if (zoneData.state === 'captured' && zoneData.owner) {
        state = 'captured';
    }
    
    // Mostrar UI según estado
    if (state === 'free') {
        showFreeState(zoneData);
    } else if (state === 'contested') {
        showContestedState(zoneData, gangColors);
    } else if (state === 'captured') {
        showCapturedState(zoneData, gangColors);
    }
    
    $('#territory-ui').fadeIn(300);
    currentState = state;
}

function hideUI() {
    $('.territory-card.active').addClass('closing');
    
    setTimeout(() => {
        $('#territory-ui').fadeOut(300);
        $('.territory-card').removeClass('active closing');
        
        if (timerInterval) {
            clearInterval(timerInterval);
            timerInterval = null;
        }
    }, 400);
}

function showFreeState(zoneData) {
    $('#free-state .territory-name').text(zoneData.name);
    $('#free-state').addClass('active');
}

function showContestedState(zoneData, gangColors) {
    $('#contested-state').addClass('active');
    
    if (zoneData.captureData) {
        updateCaptureProgress(zoneData.captureData, gangColors);
    }
}

function updateCaptureProgress(captureData, gangColors) {
    const container = $('#gangs-progress');
    container.empty();
    
    if (!captureData || !captureData.gangs) return;
    
    for (let gang in captureData.gangs) {
        const gangData = captureData.gangs[gang];
        const percentage = Math.min((gangData.points / 100) * 100, 100).toFixed(1);
        
        // Obtener color de la banda
        let gangColor = '#ff0000';
        if (gangColors && gangColors[gang]) {
            const color = gangColors[gang].color;
            gangColor = `rgb(${color.r}, ${color.g}, ${color.b})`;
        }
        
        const gangLabel = gangColors && gangColors[gang] ? gangColors[gang].label : gang.toUpperCase();
        
        const gangHTML = `
            <div class="gang-progress-item">
                <div class="gang-info">
                    <span class="gang-name" style="color: ${gangColor};">${gangLabel}</span>
                    <span class="gang-percentage">${percentage}%</span>
                </div>
                <div class="progress-bar-container">
                    <div class="progress-bar" style="width: ${percentage}%; background: linear-gradient(90deg, ${gangColor} 0%, ${gangColor}88 100%);"></div>
                </div>
            </div>
        `;
        
        container.append(gangHTML);
    }
}

function showCapturedState(zoneData, gangColors) {
    $('#captured-state .territory-name').text(zoneData.name);
    
    // Obtener información de la banda
    const ownerGang = gangColors && gangColors[zoneData.owner] ? gangColors[zoneData.owner] : null;
    const ownerLabel = ownerGang ? ownerGang.label : zoneData.owner.toUpperCase();
    const ownerColor = ownerGang ? `rgb(${ownerGang.color.r}, ${ownerGang.color.g}, ${ownerGang.color.b})` : '#ffffff';
    
    $('#owner-name').text(ownerLabel).css('color', ownerColor);
    
    // Verificar si está en cooldown
    if (zoneData.cooldownEnd && Date.now() / 1000 < zoneData.cooldownEnd) {
        // En cooldown
        $('#captured-status').text('EN COOLDOWN').removeClass('available').addClass('cooldown');
        $('#timer-section').show();
        $('#attack-section').hide();
        
        cooldownEnd = zoneData.cooldownEnd;
        startTimer();
    } else {
        // Disponible para atacar
        $('#captured-status').text('DISPONIBLE').removeClass('cooldown').addClass('available');
        $('#timer-section').hide();
        $('#attack-section').show();
    }
    
    $('#captured-state').addClass('active');
}

function startTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
    }
    
    timerInterval = setInterval(() => {
        const now = Date.now() / 1000;
        const remaining = Math.max(cooldownEnd - now, 0);
        
        if (remaining <= 0) {
            clearInterval(timerInterval);
            $('#captured-status').text('DISPONIBLE').removeClass('cooldown').addClass('available');
            $('#timer-section').hide();
            $('#attack-section').show();
            return;
        }
        
        const hours = Math.floor(remaining / 3600);
        const minutes = Math.floor((remaining % 3600) / 60);
        const seconds = Math.floor(remaining % 60);
        
        $('#hours').text(String(hours).padStart(2, '0'));
        $('#minutes').text(String(minutes).padStart(2, '0'));
        $('#seconds').text(String(seconds).padStart(2, '0'));
    }, 1000);
}