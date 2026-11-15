import 'dart:async';
import 'package:flutter/material.dart';

enum UnitSize { small, medium, large }

enum AttackType { antiLarge, antiSmall, balanced }
enum CombatMode { attack, hold, move }

double damageMultiplier(AttackType attack, UnitSize target) {
  if (attack == AttackType.balanced) return 1.0;
  if (attack == AttackType.antiLarge) {
    return target == UnitSize.large ? 1.5 : target == UnitSize.medium ? 1.0 : 0.7;
  }
  return target == UnitSize.small ? 1.5 : target == UnitSize.medium ? 1.0 : 0.7;
}

abstract class CombatUnit {
  Offset get p;
  set p(Offset value);
  Offset? get goal;
  set goal(Offset? value);
  int get hp;
  set hp(int value);
  int get cooldown;
  set cooldown(int value);
  CombatMode get mode;
  set mode(CombatMode value);
  CombatUnit? get attackTarget;
  set attackTarget(CombatUnit? value);
  Offset? get home;
  set home(Offset? value);
  bool get assisting;
  set assisting(bool value);
  UnitSize get size;
  AttackType get attackType;
  double get range;
  double get speed;
  int get damage;
}

class Soldier extends CombatUnit {
  Soldier(this.p, this.marine);
  Offset p;
  Offset? goal;
  List<Offset> waypoints=[];
  Offset? routedGoal;
  bool marine;
  int? ore;
  bool carrying = false;
  int miningTicks = 0;
  int hp = 100;
  UnitSize size = UnitSize.small;
  AttackType attackType = AttackType.antiLarge;
  int cooldown = 0;
  CombatUnit? attackTarget;
  @override double get range => 145;
  @override double get speed => 2.5;
  @override int get damage => 10;
  CombatMode mode = CombatMode.attack;
  Offset? home;
  bool assisting = false;
}
class CombatAi {
  static void tick(CombatUnit unit, {required List<Soldier> friendly, required List<Soldier> hostile}) {
    if(unit.cooldown>0)unit.cooldown--;
    final assigned=unit.attackTarget;
    CombatUnit? target;
    if(assigned!=null && hostile.contains(assigned) && assigned.hp>0) {
      target=assigned;
    } else {
      unit.attackTarget=null;
      var nearest=double.infinity;
      for(final candidate in hostile) {
        if(candidate.hp<=0)continue;
        final distance=(candidate.p-unit.p).distance;
        final detect=unit.mode==CombatMode.hold?unit.range:360.0;
        if(distance<=detect && distance<nearest) {
          nearest=distance;target=candidate;
        }
      }
    }
    if(target==null) {
      if(unit.assisting && unit.home!=null) {
        unit.goal=unit.home;
        unit.assisting=false;
      }
      return;
    }
    final distance=(target.p-unit.p).distance;
    if(distance<=unit.range) {
      if(unit.cooldown==0) {
        target.hp-=(unit.damage*damageMultiplier(unit.attackType,target.size)).round();
        unit.cooldown=12;
        if(target.hp>0) {
          for(final ally in friendly) {
            if(identical(ally,unit)||!ally.marine||ally.hp<=0||ally.mode==CombatMode.hold||ally.attackTarget!=null)continue;
            if((ally.p-unit.p).distance<=300) {
              ally.home ??= ally.p;
              ally.assisting=true;
              ally.attackTarget=target;
            }
          }
        }
      }
    } else if(unit.mode==CombatMode.attack && distance<=360 && unit.goal==null) {
      final delta=target.p-unit.p;
      if(delta.distance>0)unit.p=Terrain.advance(unit.p,target.p,unit.speed);
    }
  }
}

class Terrain {
  static const world=Size(1800,1200);
  static final obstacles=<Rect>[
    const Rect.fromLTWH(620,70,270,240),
    const Rect.fromLTWH(1010,80,360,230),
    const Rect.fromLTWH(1320,430,330,220),
    const Rect.fromLTWH(600,720,310,320),
    const Rect.fromLTWH(1050,930,440,210),
  ];
  static bool blocked(Offset point){
    if(point.dx<12||point.dy<12||point.dx>1788||point.dy>1188)return true;
    return obstacles.any((r)=>r.inflate(12).contains(point));
  }
  static Offset advance(Offset from,Offset toward,double speed){
    final delta=toward-from;
    if(delta.distance<0.01)return from;
    final step=delta/delta.distance*(delta.distance<speed?delta.distance:speed);
    final direct=from+step;
    if(!blocked(direct))return direct;
    final x=Offset(from.dx+step.dx,from.dy);
    if(!blocked(x))return x;
    final y=Offset(from.dx,from.dy+step.dy);
    if(!blocked(y))return y;
    return from;
  }
  // A* on a coarse collision grid; unexplored terrain is still navigable.
  static List<Offset> route(Offset from, Offset to){
    const cell=30.0, cols=60, rows=40;
    int id(int x,int y)=>y*cols+x;
    Offset center(int k)=>Offset((k%cols+0.5)*cell,(k~/cols+0.5)*cell);
    final sx=(from.dx/cell).floor().clamp(0,cols-1);
    final sy=(from.dy/cell).floor().clamp(0,rows-1);
    var tx=(to.dx/cell).floor().clamp(0,cols-1);
    var ty=(to.dy/cell).floor().clamp(0,rows-1);
    if(blocked(center(id(tx,ty)))){
      var best=double.infinity;
      for(var y=0;y<rows;y++)for(var x=0;x<cols;x++){
        final p=center(id(x,y));
        if(blocked(p))continue;
        final d=(p-to).distanceSquared;
        if(d<best){best=d;tx=x;ty=y;}
      }
    }
    final start=id(sx,sy),end=id(tx,ty);
    final cost=List<double>.filled(cols*rows,double.infinity);
    final parent=List<int>.filled(cols*rows,-1);
    final open=<int>[start];
    final closed=<int>{};
    cost[start]=0;
    double heuristic(int k)=>(center(k)-center(end)).distance;
    while(open.isNotEmpty){
      var bestIndex=0;
      for(var i=1;i<open.length;i++){
        if(cost[open[i]]+heuristic(open[i])<cost[open[bestIndex]]+heuristic(open[bestIndex]))bestIndex=i;
      }
      final current=open.removeAt(bestIndex);
      if(current==end)break;
      if(!closed.add(current))continue;
      final x=current%cols,y=current~/cols;
      for(var dy=-1;dy<=1;dy++)for(var dx=-1;dx<=1;dx++){
        if(dx==0&&dy==0)continue;
        final nx=x+dx,ny=y+dy;
        if(nx<0||ny<0||nx>=cols||ny>=rows)continue;
        final next=id(nx,ny);
        if(closed.contains(next)||blocked(center(next)))continue;
        if(dx!=0&&dy!=0&&(blocked(center(id(nx,y)))||blocked(center(id(x,ny)))))continue;
        final tentative=cost[current]+(dx!=0&&dy!=0?1.41421356237:1)*cell;
        if(tentative>=cost[next])continue;
        cost[next]=tentative;parent[next]=current;
        if(!open.contains(next))open.add(next);
      }
    }
    if(start!=end&&parent[end]<0)return [];
    final reversed=<Offset>[];
    var cursor=end;
    while(cursor!=start&&cursor>=0){
      reversed.add(center(cursor));
      cursor=parent[cursor];
    }
    return reversed.reversed.toList();
  }
  static void paint(Canvas c){
    final p=Paint()..style=PaintingStyle.fill;
    c.drawRect(const Rect.fromLTWH(0,0,1800,1200),p..color=const Color(0xff394d3d));
    // Deterministic ground patches give the battlefield a readable scale.
    for(var i=0;i<210;i++){
      final x=((i*173+67)%1780).toDouble()+10;
      final y=((i*127+39)%1180).toDouble()+10;
      final at=Offset(x,y);
      if(blocked(at))continue;
      p.color=i%3==0?const Color(0xff4c6045):i%3==1?const Color(0xff30473a):const Color(0xff526049);
      c.drawOval(Rect.fromCenter(center:at,width:32+(i%5)*15.0,height:16+(i%4)*10.0),p);
    }
    // Roads follow the open corridors between impassable ridges.
    final road=Path()..moveTo(260,270)..cubicTo(390,390,420,500,560,505)
      ..cubicTo(740,500,900,570,990,610)..cubicTo(1100,670,1130,710,1190,760);
    p..color=const Color(0xff5a5544)..style=PaintingStyle.stroke
      ..strokeWidth=108..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    c.drawPath(road,p);
    p..color=const Color(0xff887b5b)..strokeWidth=84;
    c.drawPath(road,p);
    p..color=const Color(0xff9d8c65)..strokeWidth=54;
    c.drawPath(road,p);
    p.style=PaintingStyle.fill;
    // Layered rock plateaus replace the former lake.
    for(final r in obstacles){
      c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(40)),
        p..color=const Color(0xff202d29));
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(9),const Radius.circular(33)),
        p..color=const Color(0xff505e50));
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(23),const Radius.circular(25)),
        p..color=const Color(0xff75806b));
      for(var j=0;j<4;j++){
        final inset=37+j*17.0;
        final top=r.top+inset;
        if(top>=r.bottom-30)break;
        c.drawLine(Offset(r.left+34,top),Offset(r.right-34,top+9),
          p..color=j.isEven?const Color(0xffa0a38a):const Color(0xff424f43)
            ..style=PaintingStyle.stroke..strokeWidth=5);
      }
      p.style=PaintingStyle.fill;
    }
    // Small stones and shrubs are visual-only, not additional collision.
    for(var i=0;i<140;i++){
      final at=Offset(((i*239+97)%1740).toDouble()+30,
        ((i*157+53)%1140).toDouble()+30);
      if(blocked(at))continue;
      p.color=i.isEven?const Color(0xff263e32):const Color(0xff89907b);
      c.drawCircle(at,2.0+(i%4)*1.5,p);
    }
  }
}

class FogOfWar {
  static const cell=40.0;
  static const columns=45, rows=30;
  final explored=List<bool>.filled(columns*rows,false);
  final visible=List<bool>.filled(columns*rows,false);
  void update(List<Soldier> units,List<Offset> bases,List<Offset> barracks){
    visible.fillRange(0,visible.length,false);
    for(final u in units){if(u.hp>0)reveal(u.p,190);}
    for(final b in bases)reveal(b,245);
    for(final b in barracks)reveal(b,170);
  }
  void reveal(Offset at,double radius){
    final left=((at.dx-radius)/cell).floor().clamp(0,columns-1);
    final right=((at.dx+radius)/cell).floor().clamp(0,columns-1);
    final top=((at.dy-radius)/cell).floor().clamp(0,rows-1);
    final bottom=((at.dy+radius)/cell).floor().clamp(0,rows-1);
    for(var y=top;y<=bottom;y++)for(var x=left;x<=right;x++){
      final center=Offset((x+0.5)*cell,(y+0.5)*cell);
      if((center-at).distance<=radius){
        final index=y*columns+x;
        visible[index]=true;explored[index]=true;
      }
    }
  }
  bool canSee(Offset at){
    final x=(at.dx/cell).floor(),y=(at.dy/cell).floor();
    return x>=0&&x<columns&&y>=0&&y<rows&&visible[y*columns+x];
  }
  void paint(Canvas canvas,{double sx=1,double sy=1}){
    final p=Paint();
    for(var y=0;y<rows;y++)for(var x=0;x<columns;x++){
      final index=y*columns+x;
      if(visible[index])continue;
      p.color=explored[index]?const Color(0xb9000000):const Color(0xff080e13);
      canvas.drawRect(Rect.fromLTWH(x*cell*sx,y*cell*sy,cell*sx+0.5,cell*sy+0.5),p);
    }
  }
}

class RtsScreen extends StatefulWidget {
  const RtsScreen({super.key});
  @override
  State<RtsScreen> createState()=>_RtsState();
}
class _RtsState extends State<RtsScreen> {
  final soldiers=<Soldier>[];
  final fog=FogOfWar();
  final bases=<Offset>[const Offset(260,260)];
  final barracks=<Offset>[];
  Offset? selectedBarracks;
  final rocks=<Offset>[const Offset(425,165),const Offset(485,200),const Offset(510,265),const Offset(495,335),const Offset(435,395),const Offset(380,420),const Offset(320,440),const Offset(245,445),const Offset(160,410),const Offset(110,345),const Offset(105,265),const Offset(140,185),const Offset(1150,750),const Offset(1250,800)];
  late final List<int> oreRemaining=List<int>.filled(rocks.length,1500);
  final chosen=<Soldier>{};
  final enemies=<Soldier>[
    Soldier(const Offset(850,420),true),
    Soldier(const Offset(920,470),true),
    Soldier(const Offset(990,420),true),
  ];
  Offset? selectedBase;
  late final Timer timer;
  Offset camera=Offset.zero;
  Offset? begin,end;
  Size view=Size.zero;
  int cash=250;
  bool? queue;
  Offset? trainingAt;
  int ticks=0;
  _RtsState() {
    for(var i=0;i<4;i++) soldiers.add(Soldier(Offset(200+i*30.0,340),false));
    fog.update(soldiers,bases,barracks);
  }
  @override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:50),(_)=>step());}
  @override void dispose(){timer.cancel();super.dispose();}
  void step(){
    if(!mounted)return;
    setState((){
      if(queue!=null && ++ticks >= (queue!?100:60)){
        final origin=trainingAt ?? bases.first;
        soldiers.add(Soldier(origin+const Offset(80,60),queue!));
        queue=null;trainingAt=null;ticks=0;
      }
      for(final unit in [...soldiers,...enemies]) {
        if(unit.cooldown>0)unit.cooldown--;
        if(!unit.marine || unit.hp<=0)continue;
        CombatAi.tick(unit, friendly: enemies.contains(unit)?enemies:soldiers, hostile: enemies.contains(unit)?soldiers:enemies);
      }
      soldiers.removeWhere((u)=>u.hp<=0);
      enemies.removeWhere((u)=>u.hp<=0);
      chosen.removeWhere((u)=>!soldiers.contains(u));
      fog.update(soldiers,bases,barracks);
      for(final u in soldiers){
        if(u.attackTarget!=null && !enemies.contains(u.attackTarget))u.attackTarget=null;
      }
      for(final s in soldiers){
        if(s.goal!=null){
          final delta=s.goal!-s.p;
          if(delta.distance<4){s.p=s.goal!;s.goal=null;}
          else{
            if(s.routedGoal!=s.goal){
              s.waypoints=Terrain.route(s.p,s.goal!);
              s.routedGoal=s.goal;
            }
            while(s.waypoints.isNotEmpty&&(s.waypoints.first-s.p).distance<7){
              s.waypoints.removeAt(0);
            }
            final target=s.waypoints.isNotEmpty?s.waypoints.first:s.goal!;
            s.p=Terrain.advance(s.p,target,3.5);
          }
        }else if(!s.marine && s.ore!=null){
          var index=s.ore!;
          if(!s.carrying && oreRemaining[index]<=0){
            index=nearestOre(s.p);
            s.ore=index<0?null:index;
            s.miningTicks=0;
            if(index<0)continue;
          }
          if(s.carrying){
            final base=bases.reduce((a,b)=>(a-s.p).distance<(b-s.p).distance?a:b);
            if((s.p-base).distance>65){
              s.goal=base+const Offset(50,30);
            }else{
              cash+=5;
              s.carrying=false;
              s.miningTicks=0;
            }
          }else{
            final rock=rocks[index];
            if((s.p-rock).distance>28){
              s.goal=rock+const Offset(-20,0);
            }else if(++s.miningTicks>=24){
              oreRemaining[index]=(oreRemaining[index]-5).clamp(0,1500);
              s.carrying=true;
              s.miningTicks=0;
            }
          }
        }
      }
    });
  }
  int nearestOre(Offset from){
    var best=-1;
    var distance=double.infinity;
    for(var i=0;i<rocks.length;i++){
      if(oreRemaining[i]<=0)continue;
      final d=(rocks[i]-from).distance;
      if(d<distance){distance=d;best=i;}
    }
    return best;
  }
  void train(bool marine){
    final cost=marine?75:50;
    if(queue!=null||cash<cost)return;
    if(marine && selectedBarracks==null)return;
    if(!marine && selectedBase==null)return;
    setState((){cash-=cost;queue=marine;trainingAt=marine?selectedBarracks:selectedBase;ticks=0;});
  }
  void buildBase(){
    final workers=chosen.where((s)=>!s.marine);
    if(workers.isEmpty||cash<400)return;
    final pos=workers.first.p;
    if(bases.any((b)=>(b-pos).distance<230))return;
    setState((){cash-=400;bases.add(pos);selectedBase=pos;chosen.clear();});
  }
  void buildBarracks(){
    final workers=chosen.where((u)=>!u.marine);
    if(workers.isEmpty||cash<200)return;
    final pos=workers.first.p+const Offset(65,0);
    if(bases.any((b)=>(b-pos).distance<90)||barracks.any((b)=>(b-pos).distance<85))return;
    setState((){cash-=200;barracks.add(pos);selectedBarracks=pos;selectedBase=null;chosen.clear();});
  }
  void command(Offset at){
    final p=at+camera;
    final hits=soldiers.where((s)=>(s.p-p).distance<22);
    if(hits.isNotEmpty){setState((){selectedBase=null;selectedBarracks=null;chosen..clear()..add(hits.first);});return;}
    final enemyHits=enemies.where((e)=>(e.p-p).distance<22);
    if(enemyHits.isNotEmpty && chosen.any((u)=>u.marine)){
      setState((){for(final u in chosen.where((u)=>u.marine)){u.attackTarget=enemyHits.first;u.mode=CombatMode.attack;u.goal=null;}});
      return;
    }
    for(final base in bases){
      if((base-p).dx.abs()<60 && (base-p).dy.abs()<45){
        setState((){selectedBase=base;selectedBarracks=null;chosen.clear();});return;
      }
    }
    for(final barrack in barracks){
      if((barrack-p).dx.abs()<50 && (barrack-p).dy.abs()<40){
        setState((){selectedBarracks=barrack;selectedBase=null;chosen.clear();});return;
      }
    }
    var ore=-1;
    for(var i=0;i<rocks.length;i++){if(oreRemaining[i]>0 && (rocks[i]-p).distance<38)ore=i;}
    setState((){
      var i=0;
      for(final s in chosen){
        s.attackTarget=null;
        s.mode=CombatMode.move;
        s.assisting=false;
        s.home=null;
        s.ore=ore>=0&&!s.marine?ore:null;
        s.carrying=false;
        s.miningTicks=0;
        s.goal=ore>=0&&!s.marine?rocks[ore]+const Offset(-20,0):p+Offset((i++%4)*18.0,0);
      }
    });
  }
  void moveCamera(double dx,double dy)=>setState((){
    camera=Offset((camera.dx+dx).clamp(0,1400).toDouble(),
                  (camera.dy+dy).clamp(0,900).toDouble());
  });
  Widget _action(String label,VoidCallback action)=>SizedBox(
    height:29,
    child:OutlinedButton(
      style:OutlinedButton.styleFrom(
        padding:const EdgeInsets.symmetric(horizontal:7),
        foregroundColor:Colors.cyanAccent,
        side:const BorderSide(color:Colors.blueGrey),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(3)),
      ),
      onPressed:action,
      child:Text(label,style:const TextStyle(fontSize:11)),
    ),
  );
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor: const Color(0xff182b29),
    body:SafeArea(child:LayoutBuilder(builder:(context,c){
      view=Size(c.maxWidth,(c.maxHeight-174).clamp(1.0,double.infinity).toDouble());
      return Column(children:[
        Container(height:48,color: const Color(0xff22333c),child:Row(children:[
          const SizedBox(width:12),const Text('RTS 광산',style:TextStyle(color:Colors.white)),
          const Spacer(),Text('미네랄: $cash',style:const TextStyle(color:Colors.cyanAccent)),
          const SizedBox(width:12)])),
        Expanded(child:GestureDetector(
          behavior:HitTestBehavior.opaque,
          onTapUp:(d)=>command(d.localPosition),
          onPanStart:(d)=>setState((){begin=d.localPosition;end=begin;}),
          onPanUpdate:(d)=>setState((){end=d.localPosition;}),
          onPanEnd:(_)=>setState((){
            if(begin!=null&&end!=null&&(begin!-end!).distance>12){
              final rect=Rect.fromPoints(begin!+camera,end!+camera);
              selectedBase=null;selectedBarracks=null;
              chosen..clear()..addAll(soldiers.where((s)=>rect.contains(s.p)));
            }
            begin=null;end=null;
          }),
          child:CustomPaint(size:Size.infinite,painter:_Map(soldiers,bases,rocks,chosen,camera,begin,end,enemies,barracks,fog)))),
        Container(
          height:126,
          padding:const EdgeInsets.all(5),
          color:const Color(0xff17252e),
          child:Row(children:[
            Expanded(flex:2,child:LayoutBuilder(builder:(context,mini){
              return GestureDetector(
              behavior:HitTestBehavior.opaque,
              onTapDown:(d)=>setState((){
                final world=Offset(
                  d.localPosition.dx/mini.maxWidth*1800,
                  d.localPosition.dy/mini.maxHeight*1200,
                );
                if(chosen.isNotEmpty){
                  var i=0;
                  for(final unit in chosen){
                    unit.goal=world+Offset((i++%4)*16.0,0);
                    unit.attackTarget=null;
                    unit.mode=CombatMode.move;
                    unit.ore=null;
                    unit.routedGoal=null;
                    unit.waypoints=[];
                  }
                }else{
                  camera=Offset(
                    (world.dx-view.width/2).clamp(0,(Terrain.world.width-view.width).clamp(0.0,double.infinity)).toDouble(),
                    (world.dy-view.height/2).clamp(0,(Terrain.world.height-view.height).clamp(0.0,double.infinity)).toDouble(),
                  );
                }
              }),
              child:ClipRect(child:CustomPaint(
                painter:_MiniMap(soldiers,bases,rocks,camera,view,barracks,fog),
                child:const SizedBox.expand(),
              )),
              );
            })),
            const SizedBox(width:6),
            Expanded(flex:2,child:Container(
              alignment:Alignment.center,
              decoration:BoxDecoration(color:const Color(0xff243640),border:Border.all(color:Colors.blueGrey)),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(selectedBarracks!=null?'병영':selectedBase!=null?'본부':chosen.isEmpty?'선택 없음':chosen.length==1?(chosen.first.marine?'Soldier':'Engineer'):'유닛 ${chosen.length}기',
                  textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
                const SizedBox(height:5),
                Text(selectedBarracks!=null?'Soldier 생산':selectedBase!=null?'Engineer 생산':chosen.isEmpty?'유닛이나 기지를 선택하세요':chosen.any((u)=>!u.marine)?'채굴 / 이동 / 확장':'이동 / 자동 공격',
                  textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,fontSize:11)),
                if(queue!=null)Text('생산 중: ${queue!?'Soldier':'Engineer'}',style:const TextStyle(color:Colors.cyanAccent,fontSize:11)),
              ]),
            )),
            const SizedBox(width:6),
            Expanded(flex:3,child:Container(
              padding:const EdgeInsets.all(4),
              decoration:BoxDecoration(color:const Color(0xff243640),border:Border.all(color:Colors.blueGrey)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('명령',style:TextStyle(color:Colors.white70,fontSize:11)),
                Expanded(child:SingleChildScrollView(child:Wrap(spacing:4,runSpacing:4,children:[
                  if(selectedBase!=null) _action('Engineer 50',()=>train(false)),
                  if(selectedBarracks!=null) _action('Soldier 75',()=>train(true)),
                  if(chosen.any((u)=>!u.marine)) ...[
                    _action('본부 400',buildBase),
                    _action('병영 200',buildBarracks),
                  ],
                  if(chosen.any((u)=>u.marine)) ...[
                    _action('홀드',()=>setState((){for(final u in chosen.where((u)=>u.marine)){u.mode=CombatMode.hold;u.goal=null;u.attackTarget=null;u.assisting=false;u.home=null;}})),
                    _action('어택',()=>setState((){for(final u in chosen.where((u)=>u.marine)){u.mode=CombatMode.attack;u.goal=null;u.attackTarget=null;u.assisting=false;u.home=null;}})),
                  ],
                  if(chosen.isNotEmpty) _action('정지',()=>setState((){
                    for(final u in chosen){u.goal=null;u.ore=null;u.carrying=false;u.miningTicks=0;u.attackTarget=null;}
                  })),
                  if(selectedBase==null&&selectedBarracks==null&&chosen.isEmpty)const Text('유닛 또는 기지 선택',style:TextStyle(color:Colors.white54,fontSize:11)),
                  _action('◀',()=>moveCamera(-150,0)),
                  _action('▲',()=>moveCamera(0,-150)),
                  _action('▶',()=>moveCamera(150,0)),
                  _action('▼',()=>moveCamera(0,150)),
                ]))),
              ]),
            )),
          ]),
        ),
      ]);
    })),
  );
}
class _Map extends CustomPainter{
  _Map(this.units,this.bases,this.rocks,this.selected,this.camera,this.start,this.end,this.enemies,this.barracks,this.fog);
  final FogOfWar fog;
  final List<Offset> barracks;
  final List<Soldier> enemies;
  final List<Soldier> units;
  final List<Offset> bases,rocks;
  final Set<Soldier> selected;
  final Offset camera;
  final Offset? start,end;
  @override void paint(Canvas c,Size size){
    c.drawColor(const Color(0xff30473d),BlendMode.src);
    c.save();c.translate(-camera.dx,-camera.dy);
    Terrain.paint(c);
    final p=Paint();
    p.color = const Color(0x225ea487);
    for(var x=0.0;x<1800;x+=80)c.drawLine(Offset(x,0),Offset(x,1200),p);
    for(var y=0.0;y<1200;y+=80)c.drawLine(Offset(0,y),Offset(1800,y),p);
    for(final o in rocks){
      final crystal=Path()..moveTo(o.dx,o.dy-34)..lineTo(o.dx+18,o.dy-15)..lineTo(o.dx+27,o.dy+15)..lineTo(o.dx,o.dy+32)..lineTo(o.dx-25,o.dy+12)..lineTo(o.dx-16,o.dy-18)..close();
      p.color = const Color(0xff0a6177);c.drawPath(crystal,p);
      p.color = const Color(0xff39e4ff);c.drawPath(Path()..moveTo(o.dx,o.dy-34)..lineTo(o.dx+18,o.dy-15)..lineTo(o.dx,o.dy+32)..close(),p);
      p.color = const Color(0xffa0f6ff);c.drawPath(Path()..moveTo(o.dx,o.dy-34)..lineTo(o.dx-16,o.dy-18)..lineTo(o.dx,o.dy+32)..close(),p);
    }
    // Pseudo-isometric building silhouettes: visible roofs and south-facing walls.
    void building(Offset at,double w,double depth,double height,Color roof,Color wall,String name){
      final footprint=Rect.fromCenter(center:at,width:w,height:depth);
      final top=footprint.shift(Offset(0,-height));
      final shadow=Path()..moveTo(footprint.left,footprint.bottom)
        ..lineTo(footprint.right,footprint.bottom)
        ..lineTo(top.right,top.bottom)..lineTo(top.left,top.bottom)..close();
      c.drawPath(shadow,p..color=wall);
      c.drawRRect(RRect.fromRectAndRadius(top,const Radius.circular(7)),p..color=roof);
      c.drawLine(top.bottomLeft,top.bottomRight,
        p..color=const Color(0xffc4c9b7)..style=PaintingStyle.stroke..strokeWidth=3);
      p.style=PaintingStyle.fill;
      label(c,name,at+Offset(-w*0.36,-height-6),Colors.white);
    }
    for(final b in bases){
      building(b,120,90,32,const Color(0xff718a99),const Color(0xff344955),'COMMAND');
    }
    for(final b in barracks){
      building(b,100,80,27,const Color(0xff99735b),const Color(0xff503c36),'BARRACKS');
    }
    fog.paint(c);
    for(final u in [...units,...enemies]){
      if(enemies.contains(u)&&!fog.canSee(u.p))continue;
      // Ground rings are flattened ellipses; units rise above their footprints.
      if(selected.contains(u)){
        p..color=Colors.lightGreenAccent..style=PaintingStyle.stroke..strokeWidth=2;
        c.drawOval(Rect.fromCenter(center:u.p+const Offset(0,5),width:40,height:19),p);
        p.style=PaintingStyle.fill;
      }
      c.drawOval(Rect.fromCenter(center:u.p+const Offset(3,7),width:25,height:12),
        p..color=const Color(0x88000000));
      p.color=enemies.contains(u)?Colors.red:(u.marine?Colors.blue:Colors.amber);
      c.drawOval(Rect.fromCenter(center:u.p+const Offset(0,-8),width:25,height:32),p);
      c.drawOval(Rect.fromCenter(center:u.p+const Offset(-3,-15),width:12,height:10),
        p..color=const Color(0x99ffffff));
      p.color=Colors.black54;
      c.drawRect(Rect.fromLTWH(u.p.dx-15,u.p.dy-23,30,4),p);
      p.color=u.hp>40?Colors.lightGreenAccent:Colors.orangeAccent;
      c.drawRect(Rect.fromLTWH(u.p.dx-15,u.p.dy-23,30*(u.hp.clamp(0,100)/100),4),p);
      label(c,u.marine?'B':'G',u.p+const Offset(-5,-8),Colors.black);
    }
    c.restore();
    if(start!=null&&end!=null){
      p..color=Colors.lightGreenAccent..style=PaintingStyle.stroke;
      c.drawRect(Rect.fromPoints(start!,end!),p);
    }
  }
  void label(Canvas c,String s,Offset at,Color color){
    final t=TextPainter(text:TextSpan(text:s,style:TextStyle(color:color,fontSize:12,fontWeight:FontWeight.bold)),textDirection:TextDirection.ltr)..layout();
    t.paint(c,at);
  }
  @override bool shouldRepaint(covariant _Map old)=>true;
}

class _MiniMap extends CustomPainter {
  _MiniMap(this.units,this.bases,this.rocks,this.camera,this.view,this.barracks,this.fog);
  final FogOfWar fog;
  final List<Offset> barracks;
  final List<Soldier> units;
  final List<Offset> bases,rocks;
  final Offset camera;
  final Size view;
  @override void paint(Canvas canvas,Size size){
    canvas.drawColor(const Color(0xff415541),BlendMode.src);
    final sx=size.width/1800,sy=size.height/1200;
    final p=Paint();
    for(var i=0;i<Terrain.obstacles.length;i++){
      final r=Terrain.obstacles[i];
      p.color=const Color(0xff92917b);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left*sx,r.top*sy,r.width*sx,r.height*sy),const Radius.circular(3)),p);
    }
    for(final rock in rocks){
      p.color=Colors.cyanAccent;
      canvas.drawCircle(Offset(rock.dx*sx,rock.dy*sy),3,p);
    }
    for(final base in bases){
      p.color=Colors.blueGrey.shade200;
      canvas.drawRect(Rect.fromCenter(center:Offset(base.dx*sx,base.dy*sy),width:8,height:7),p);
    }
    for(final b in barracks){
      p.color=Colors.brown;
      canvas.drawRect(Rect.fromCenter(center:Offset(b.dx*sx,b.dy*sy),width:7,height:6),p);
    }
    for(final unit in units){
      p.color=unit.marine?Colors.lightBlue:Colors.amber;
      canvas.drawCircle(Offset(unit.p.dx*sx,unit.p.dy*sy),2,p);
    }
    fog.paint(canvas,sx:sx,sy:sy);
    p..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.5;
    canvas.drawRect(Rect.fromLTWH(camera.dx*sx,camera.dy*sy,view.width*sx,view.height*sy),p);
  }
  @override bool shouldRepaint(covariant _MiniMap old)=>true;
}
