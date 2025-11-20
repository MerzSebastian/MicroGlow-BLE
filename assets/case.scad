$fn=150;

translate([30,00,0]) difference(){
    //main body
    union(){
        
        translate([-14.5,00,0]) cube([29,15.5,25]);
        translate([0,00,0]) cylinder(d=29, h=25);
    }

    
    cylinder(d=24, h=21-13.5);
    translate([0,0,21-13.5]) cylinder(d1=19, d2=18.5, h=13.5);
    
    //top cup
    translate([0,00,23]) difference(){
        cylinder(d=27.1, h=2);
    }

        cylinder(d=11.6, h=200);
    
    
    
translate([17-30,15.5,5]) rotate([180,180,90]) union(){
    cube([1.2,23.8,18.2]);
    translate([1.2,00,(18.2-14.3)/2]) cube([3.2-1.2,23.8,14.3]);

    translate([1.2+1.5,5,5.8]) hull() {
        rotate([90,90,0]) cylinder(d=3,h=10);
        translate([0,00,5.8]) rotate([90,90,0]) cylinder(d=3,h=10);
    }
}


translate([17-30,5,20.9]) rotate([-5,0,0]) cube([13,13,3]);

translate([41.8-30,22,18]) union(){
    rotate([90,90,0]) cylinder(d=2,h=15);
    translate([0,-15,0]) rotate([90,90,0]) cylinder(d=4,h=3);
    translate([-12,-18,-2]) cube([12,3,4]);
}
}

