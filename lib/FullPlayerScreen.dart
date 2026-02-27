class FullPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> song;
  final AudioPlayer player;

  const FullPlayerScreen({
    super.key,
    required this.song,
    required this.player,
  });

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Icon(Icons.more_vert),
                ],
              ),
            ),

            Text(
              widget.song["trackName"],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.song["artistName"],
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // Rotating Disc
            RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(widget.song["artworkUrl100"]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Fake waveform bar
            Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const Spacer(),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.skip_previous, size: 40),
                const SizedBox(width: 20),
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.skip_next, size: 40),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}