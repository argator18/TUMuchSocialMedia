import 'package:flutter/material.dart';
import 'dart:math';

// Widget zur Anzeige des Haupt-Dashboards.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulierte "Naughty Scores" für die letzten 10 Tage (Werte von 0 bis 100)
    // 0 = Perfekt, 100 = Sehr schlecht
    final List<int> naughtyScores = List.generate(
      10,
      (index) => Random().nextInt(100),
    );

    // Berechnung des durchschnittlichen "Naughty Score"
    final double averageScore = naughtyScores.reduce((a, b) => a + b) / naughtyScores.length;
    final String averageScoreString = averageScore.toStringAsFixed(1);
    
    // Die Farbe des Gesamtergebnisses hängt vom Durchschnitt ab
    Color scoreColor;
    if (averageScore <= 30) {
      scoreColor = Colors.green.shade600; // Gut
    } else if (averageScore <= 65) {
      scoreColor = Colors.amber.shade700; // Mittel
    } else {
      scoreColor = Colors.red.shade600; // Schlecht
    }

    // Hilfsfunktion für die Navigationskarten
    Widget _buildNavigationCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required String routeName,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 15),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, routeName);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Gesamtpunktzahl-Karte (Naughty Score)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(
                      averageScore <= 30 ? Icons.mood : (averageScore <= 65 ? Icons.sentiment_neutral : Icons.mood_bad),
                      color: scoreColor,
                      size: 40,
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ihr aktueller "Naughty Score" (10 Tage)',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          averageScoreString,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Titel für das Diagramm
            Text(
              'Verlauf der letzten 10 Tage (Nutzung in %)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 15),

            // Das Balkendiagramm
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: naughtyScores.asMap().entries.map((entry) {
                  final index = entry.key;
                  final score = entry.value.toDouble();
                  
                  // Skaliere den Score auf die Containerhöhe (max. 150 Pixel für den Balken)
                  final double barHeight = score * 1.5;
                  
                  // Farbe des Balkens
                  Color barColor;
                  if (score <= 30) {
                    barColor = Colors.green.shade400;
                  } else if (score <= 65) {
                    barColor = Colors.amber.shade400;
                  } else {
                    barColor = Colors.red.shade400;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Balken
                      Container(
                        height: barHeight,
                        width: 20,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Tag-Beschriftung
                      Text(
                        'Tag ${10 - index}', // 10, 9, 8, ...
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // NEUE NAVIGATIONSELEMENTE
            Text(
              'Einstellungen und Anpassungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 15),

            _buildNavigationCard(
              title: 'Langfristige Ziele anpassen',
              subtitle: 'Ihre Sparziele und Nutzungs-Limits überprüfen.',
              icon: Icons.track_changes,
              color: Theme.of(context).colorScheme.primary,
              routeName: '/goals',
            ),
            
            // Navigator-Karte für den Motivationsgrund (ReasonPage) - WIEDER HINZUGEFÜGT
            _buildNavigationCard(
              title: 'Motivationsgrund ändern',
              subtitle: 'Ihre Begründung für die App-Nutzung bearbeiten (Text/Sprache/Lern-Grund).',
              icon: Icons.campaign,
              color: Theme.of(context).colorScheme.secondary,
              routeName: '/reason',
            ),
            
          ],
        ),
      ),
    );
  }
}


