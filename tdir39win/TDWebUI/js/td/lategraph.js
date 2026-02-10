function loadLateData() {
    $.get('/war/latedata.json', function (data) {
    	var latemins = [];
    	var indx;
    	for(indx = 0; indx < data.latedata.length; ++indx) {
    		var pt = data.latedata[indx];
    		var y = pt.late;
    		latemins.push({ x: Date.UTC(2015, 1, 1, pt.hour, pt.min), y: y });
    	}
        $('#lateMinuteGraph').highcharts({
            chart: {
                zoomType: 'x'
            },
            title: {
                text: 'Late Minutes'
            },
            subtitle: {
                text: document.ontouchstart === undefined ?
                    'Click and drag in the plot area to zoom in' :
                    'Pinch the chart to zoom in'
            },
            xAxis: {
                type: 'datetime',
                dateTimeLabelFormats : {
                    hour: '%I %p',
                    minute: '%I:%M %p'
                }
            },
            yAxis: {
                title: {
                    text: 'Minutes'
                }
            },
            legend: {
                enabled: false
            },
            plotOptions: {
                area: {
                    fillColor: {
                        linearGradient: {
                            x1: 0,
                            y1: 0,
                            x2: 0,
                            y2: 1
                        },
                        stops: [
                            [0, Highcharts.getOptions().colors[0]],
                            [1, Highcharts.Color(Highcharts.getOptions().colors[0]).setOpacity(0).get('rgba')]
                        ]
                    },
                    marker: {
                        radius: 2
                    },
                    lineWidth: 1,
                    states: {
                        hover: {
                            lineWidth: 1
                        }
                    },
                    threshold: null
                }
            },

            series: [{
                type: 'area',
                name: 'Late Minutes',
                data: latemins
            }]
        });
    });
}
