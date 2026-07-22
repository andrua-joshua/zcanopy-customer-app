import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerX extends StatefulWidget {
  final String video_url;

  const VideoPlayerX({super.key, required this.video_url});

  @override
  State<VideoPlayerX> createState() => _videoState();
}

class _videoState extends State<VideoPlayerX> {
  late VideoPlayerController _controller;
  // ChewieController? _chewieController;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();

   // _controller = VideoPlayerController.asset(widget.video_url)
     _controller=VideoPlayerController.networkUrl(Uri.parse(widget.video_url))
      ..initialize().then((_) {
        /*  _chewieController=ChewieController(
          videoPlayerController: _controller,
          autoPlay: false,
          looping:false,
          aspectRatio: _controller.value.aspectRatio
        );
*/

        setState(() {
          isInitialized = true;
        });

     //   _controller.play();
        print(
            "-------------------------------------------------------->${_controller.value.isInitialized}");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
//    _chewieController?.dispose();
    super.dispose();
  }

  String formateDuration(Duration _D) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final mins = twoDigits(_D.inMinutes.remainder(60));
    final secs = twoDigits(_D.inSeconds.remainder(60));
    return "${_D.inHours > 0 ? '${twoDigits(_D.inHours)}:' : ''}$mins:$secs";
  }

  void _goFullScreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => FullScreenWidget(controller: _controller),
    ));
  }

  void _toggleVideo() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        isInitialized = false;
      } else {
        _controller.play();
        isInitialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Card(
            color: Colors.black,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              AspectRatio(
                  aspectRatio: _controller.value.aspectRatio, //16/9
                  child: Stack(alignment: Alignment.center, children: [
                    VideoPlayer(_controller),
                    Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent
                          ])),
                    ),
                    GestureDetector(
                      onTap: _toggleVideo,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isInitialized ? 0.0 : 1.0,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.brown, shape: BoxShape.circle),
                            padding: EdgeInsets.all(12),
                            child: !_controller.value.isPlaying
                                ? Icon(Icons.play_arrow,
                                    color: Colors.white, size: 50)
                                : Icon(Icons.pause,
                                    color: Colors.white, size: 50)),
                      ),
                    )
                  ])),

              //for controls
              Positioned(
                  bottom: 4,
                  left: 8,
                  right: 8,
                  child: Column(
                    children: [
                      VideoProgressIndicator(_controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: Colors.redAccent,
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.black26,
                          )),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                              },
                              icon: Icon(_controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow)),

                          //time label
                          Text(
                            "${formateDuration(_controller.value.position)}/ ${formateDuration(_controller.value.duration)}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),

                          //fullscreen button
                          IconButton(
                            onPressed: _goFullScreen,
                            icon: const Icon(Icons.fullscreen),
                            color: Colors.white,
                          )
                        ],
                      )
                    ],
                  )),
            ]))
        :Center(
          child:SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 169, 97, 14),
            )),) ;
  }
}

class FullScreenWidget extends StatefulWidget{
  final VideoPlayerController controller;
  const FullScreenWidget({Key? key, required this.controller}):super(key:key);
    
    @override
    State<FullScreenWidget> createState() => _FullScreenWidget(controller: controller);
}

class _FullScreenWidget extends State<FullScreenWidget> {
  final VideoPlayerController controller;
  bool isInitialized = false;
   _FullScreenWidget({Key? key, required this.controller});

      String formateDuration(Duration _D) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final mins = twoDigits(_D.inMinutes.remainder(60));
    final secs = twoDigits(_D.inSeconds.remainder(60));
    return "${_D.inHours > 0 ? '${twoDigits(_D.inHours)}:' : ''}$mins:$secs";
  }


@override
void initState(){
  super.initState();
       controller.play();
  }

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }

  void _toggleVideo() {
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        isInitialized = false;
      } else {
        controller.play();
        isInitialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body:controller.value.isInitialized
        ? Center(
            child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Column(children: [
            AspectRatio(
                aspectRatio: controller.value.aspectRatio, //16/9
                child: Stack(alignment: Alignment.center, children: [
                  VideoPlayer(controller),
                  Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent
                        ])),
                  ),
                    GestureDetector(
                      onTap: _toggleVideo,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isInitialized ? 0.0 : 1.0,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.brown, shape: BoxShape.circle),
                            padding: EdgeInsets.all(12),
                            child: !controller.value.isPlaying
                                ? Icon(Icons.play_arrow,
                                    color: Colors.white, size: 50)
                                : Icon(Icons.pause,
                                    color: Colors.white, size: 50)),
                      ),
                    )
                  
                ])),

                   
          ]),
        )):
        Center(child:CircularProgressIndicator(color:Colors.brown) )
        
        );
  }
}
