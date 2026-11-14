import 'dart:async';
import 'package:flutter/material.dart';

class Soldier {
  Soldier(this.p, this.marine);
  Offset p;
  Offset? goal;
  bool marine;
  int? ore;
  bool carrying = false;
}
class RtsScreen extends StatefulWidget {
  const RtsScreen({super.key});
  @override
  State<RtsScreen> createState()=>_RtsState();
}
class _RtsState extends State<RtsScreen> {
  final soldiers=<Soldier>[];
  final bases=<Offset>[const Offset(260,260)];
  final rocks=<Offset>[const Offset(425,165),const Offset(485,200),const Offset(510,265),const Offset(495,335),const Offset(435,395),const Offset(380,420),const Offset(1150,750),const Offset(1250,800)];
  final chosen=<Soldier>{};
  Offset? selectedBase;
  late final Timer timer;
  Offset camera=Offset.zero;
  Offset? begin,end;
  Size view=Size.zero;
  int cash=250;
  bool? queue;
  int ticks=0;
  _RtsState() {
    for(var i=0;i<4;i++) soldiers.add(Soldier(Offset(200+i*30.0,340),false));
  }
  @override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:50),(_)=>step());}
  @override void dispose(){timer.cancel();super.dispose();}
  void step(){
    if(!mounted)return;
    setState((){
      if(queue!=null && ++ticks >= (queue!?100:60)){
        soldiers.add(Soldier(bases.first+const Offset(80,60),queue!));
        queue=null;ticks=0;
      }
      for(final s in soldiers){
        if(s.goal!=null){
          final delta=s.goal!-s.p;
          if(delta.distance<4){s.p=s.goal!;s.goal=null;}
          else{s.p+=delta/delta.distance*3.5;}
        }else if(!s.marine && s.ore!=null){
          final rock=rocks[s.ore!];
          if(!s.carrying){
            if((s.p-rock).distance>28)s.goal=rock+const Offset(-20,0);
            else s.carrying=true;
          }else{
            final b=bases.reduce((a,b)=>(a-s.p).distance<(b-s.p).distance?a:b);
            if((s.p-b).distance>65)s.goal=b+const Offset(50,30);
            else{cash+=5;s.carrying=false;}
          }
        }
      }
    });
  }
  void train(bool marine){
    final cost=marine?75:50;
    if(queue!=null||cash<cost)return;
    setState((){cash-=cost;queue=marine;ticks=0;});
  }
  void buildBase(){
    final workers=chosen.where((s)=>!s.marine);
    if(workers.isEmpty||cash<400)return;
    final pos=workers.first.p;
    if(bases.any((b)=>(b-pos).distance<230))return;
    setState((){cash-=400;bases.add(pos);selectedBase=pos;chosen.clear();});
  }
  void command(Offset at){
    final p=at+camera;
    final hits=soldiers.where((s)=>(s.p-p).distance<22);
    if(hits.isNotEmpty){setState((){selectedBase=null;chosen..clear()..add(hits.first);});return;}
    for(final base in bases){
      if((base-p).dx.abs()<60 && (base-p).dy.abs()<45){
        setState((){selectedBase=base;chosen.clear();});return;
      }
    }
    var ore=-1;
    for(var i=0;i<rocks.length;i++){if((rocks[i]-p).distance<38)ore=i;}
    setState((){
      var i=0;
      for(final s in chosen){
        s.ore=ore>=0&&!s.marine?ore:null;
        s.carrying=false;
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
              selectedBase=null;
              chosen..clear()..addAll(soldiers.where((s)=>rect.contains(s.p)));
            }
            begin=null;end=null;
          }),
          child:CustomPaint(size:Size.infinite,painter:_Map(soldiers,bases,rocks,chosen,camera,begin,end)))),
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
                camera=Offset(
                  (world.dx-view.width/2).clamp(0,1400).toDouble(),
                  (world.dy-view.height/2).clamp(0,900).toDouble(),
                );
              }),
              child:ClipRect(child:CustomPaint(
                painter:_MiniMap(soldiers,bases,rocks,camera,view),
                child:const SizedBox.expand(),
              )),
              );
            })),
            const SizedBox(width:6),
            Expanded(flex:2,child:Container(
              alignment:Alignment.center,
              decoration:BoxDecoration(color:const Color(0xff243640),border:Border.all(color:Colors.blueGrey)),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(selectedBase!=null?'커맨드 센터':chosen.isEmpty?'선택 없음':chosen.length==1?(chosen.first.marine?'마린':'SCV'):'유닛 ${chosen.length}기',
                  textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
                const SizedBox(height:5),
                Text(selectedBase!=null?'기지 · 생산':chosen.isEmpty?'유닛이나 기지를 선택하세요':chosen.any((u)=>!u.marine)?'채굴 / 이동 / 확장':'이동 / 방어',
                  textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,fontSize:11)),
                if(queue!=null)Text('생산 중: ${queue!?'마린':'SCV'}',style:const TextStyle(color:Colors.cyanAccent,fontSize:11)),
              ]),
            )),
            const SizedBox(width:6),
            Expanded(flex:3,child:Container(
              padding:const EdgeInsets.all(4),
              decoration:BoxDecoration(color:const Color(0xff243640),border:Border.all(color:Colors.blueGrey)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('명령',style:TextStyle(color:Colors.white70,fontSize:11)),
                Expanded(child:SingleChildScrollView(child:Wrap(spacing:4,runSpacing:4,children:[
                  if(selectedBase!=null||chosen.isEmpty) ...[
                    _action('SCV 50',()=>train(false)),
                    _action('마린 75',()=>train(true)),
                  ],
                  if(chosen.any((u)=>!u.marine)) _action('기지 400',buildBase),
                  if(chosen.isNotEmpty) _action('정지',()=>setState((){
                    for(final u in chosen){u.goal=null;u.ore=null;u.carrying=false;}
                  })),
                  if(selectedBase==null&&chosen.isEmpty)const Text('유닛 또는 기지 선택',style:TextStyle(color:Colors.white54,fontSize:11)),
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
  _Map(this.units,this.bases,this.rocks,this.selected,this.camera,this.start,this.end);
  final List<Soldier> units;
  final List<Offset> bases,rocks;
  final Set<Soldier> selected;
  final Offset camera;
  final Offset? start,end;
  @override void paint(Canvas c,Size size){
    c.drawColor(const Color(0xff30473d),BlendMode.src);
    c.save();c.translate(-camera.dx,-camera.dy);
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
    for(final b in bases){
      p.color=Colors.blueGrey;c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:b,width:120,height:90),const Radius.circular(8)),p);
      label(c,'COMMAND',b+const Offset(-42,-8),Colors.white);
    }
    for(final u in units){
      p.color=u.marine?Colors.blue:Colors.amber;
      c.drawCircle(u.p,13,p);
      if(selected.contains(u)){
        p..color=Colors.lightGreenAccent..style=PaintingStyle.stroke..strokeWidth=2;
        c.drawCircle(u.p,19,p);p.style=PaintingStyle.fill;
      }
      label(c,u.marine?'M':'S',u.p+const Offset(-5,-8),Colors.black);
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
  _MiniMap(this.units,this.bases,this.rocks,this.camera,this.view);
  final List<Soldier> units;
  final List<Offset> bases,rocks;
  final Offset camera;
  final Size view;
  @override void paint(Canvas canvas,Size size){
    canvas.drawColor(const Color(0xff30473d),BlendMode.src);
    final sx=size.width/1800,sy=size.height/1200;
    final p=Paint();
    for(final rock in rocks){
      p.color=Colors.cyanAccent;
      canvas.drawCircle(Offset(rock.dx*sx,rock.dy*sy),3,p);
    }
    for(final base in bases){
      p.color=Colors.blueGrey.shade200;
      canvas.drawRect(Rect.fromCenter(center:Offset(base.dx*sx,base.dy*sy),width:8,height:7),p);
    }
    for(final unit in units){
      p.color=unit.marine?Colors.lightBlue:Colors.amber;
      canvas.drawCircle(Offset(unit.p.dx*sx,unit.p.dy*sy),2,p);
    }
    p..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.5;
    canvas.drawRect(Rect.fromLTWH(camera.dx*sx,camera.dy*sy,view.width*sx,view.height*sy),p);
  }
  @override bool shouldRepaint(covariant _MiniMap old)=>true;
}
