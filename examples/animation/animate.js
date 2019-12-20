Ext.require([
    'BasiGX.view.component.Map',
    'BasiGX.util.Animate'
]);

Ext.onReady(function() {

    var clickSelect;
    var hoverSelect;

    Ext.create('Ext.container.Container', {
        renderTo: 'map',
        layout: 'border',
        width: '100%',
        height: 600,
        items: [{
            xtype: 'panel',
            region: 'center',
            layout: 'fit',
            items: [{
                xtype: 'basigx-component-map',
                appContextPath: './resources/appContext.json'
            }],
            dockedItems: [{
                xtype: 'toolbar',
                width: 180,
                dock: 'right',
                items: [{
                    xtype: 'button',
                    text: 'Switch to hover mode',
                    pressed: false,
                    enableToggle: true,
                    handler: function(btn) {
                        hoverSelect.setActive(btn.pressed);
                        clickSelect.setActive(!btn.pressed);
                        btn.setText(btn.pressed ? 'Switch to click mode' :
                            'Switch to hover mode');
                    }
                }, {
                    xtype: 'slider',
                    name: 'duration',
                    minValue: 250,
                    maxValue: 2000,
                    value: 1000,
                    increment: 50,
                    listeners: {
                        change: function(slider) {
                            var tbText = slider.up().down('tbtext');
                            var val = slider.getValue();
                            tbText.setHtml("Duration: " + val + " ms");
                        }
                    }
                }, {
                    xtype: 'tbtext',
                    html: 'Duration: 1000 milliseconds'
                }, {
                    xtype: 'button',
                    text: 'Material Fill',
                    pressed: true,
                    toggleGroup: 'animation'
                }, {
                    xtype: 'button',
                    text: 'Flash Feature',
                    pressed: false,
                    toggleGroup: 'animation'
                }, {
                    xtype: 'button',
                    text: 'Follow Vertices',
                    pressed: false,
                    toggleGroup: 'animation'
                }, {
                    xtype: 'button',
                    text: 'Follow Segments',
                    pressed: false,
                    toggleGroup: 'animation'
                }]
            }]
        }]
    });

    var map = BasiGX.util.Map.getMapComponent().map;

    var vector = new ol.layer.Vector({
        source: new ol.source.Vector({
            url: './resources/geojson.geojson',
            format: new ol.format.GeoJSON()
        })
    });
    map.addLayer(vector);

    var defaultStyle = new ol.style.Style({
        stroke: new ol.style.Stroke({
            width: 1,
            color: [51, 153, 204, 1]
        })
    });

    clickSelect = new ol.interaction.Select({
        style: defaultStyle,
        hitTolerance: 10
    });
    hoverSelect = new ol.interaction.Select({
        condition: ol.events.condition.pointerMove,
        style: defaultStyle
    });

    map.addInteraction(clickSelect);
    map.addInteraction(hoverSelect);
    hoverSelect.setActive(false);

    var mf = Ext.ComponentQuery.query('button[text=Material Fill]')[0];
    var ff = Ext.ComponentQuery.query('button[text=Flash Feature]')[0];
    var fv = Ext.ComponentQuery.query('button[text=Follow Vertices]')[0];
    var fs = Ext.ComponentQuery.query('button[text=Follow Segments]')[0];

    var durationSlider = Ext.ComponentQuery.query('slider[name="duration"]')[0];

    var animateFeature = function(e) {
        var feature = e.selected[0];
        if (!feature) {
            return;
        }
        var evt = e.mapBrowserEvent;
        var materialFill = mf.pressed;
        var flashFeature = !materialFill && ff.pressed;
        var followVertices = !flashFeature && fv.pressed;
        var followSegments = !followVertices && fs.pressed;
        var duration = durationSlider.getValue();
        if (materialFill) {
            BasiGX.util.Animate.materialFill(feature, duration, evt, map);
        } else if (flashFeature) {
            BasiGX.util.Animate.flashFeature(feature, duration, map);
        } else if (followVertices) {
            BasiGX.util.Animate.followVertices(feature, duration, false, map);
        } else if (followSegments) {
            BasiGX.util.Animate.followVertices(feature, duration, true, map);
        }
    };

    hoverSelect.on('select', animateFeature, this);
    clickSelect.on('select', function(e) {
        animateFeature(e);
        // remove selections immediately to allow reselect
        var interactions = map.getInteractions().getArray();
        interactions.forEach(function(i) {
            if (i.getFeatures) {
                i.getFeatures().clear();
            }
        });
    });
});
