import 'package:eduspark/MentorHelp.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:confetti/confetti.dart';
import 'CaseCertificate.dart';
import 'MentorPage.dart';

class CaseStudyDetailPage extends StatefulWidget {
  final String caseStudyId;

  const CaseStudyDetailPage({required this.caseStudyId});

  @override
  _CaseStudyDetailPageState createState() => _CaseStudyDetailPageState();
}

class _CaseStudyDetailPageState extends State<CaseStudyDetailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String geminiApiKey = 'AIzaSyD062XVd6OSXKDstjBDeClAzt4S6mvlebc';
  int currentLevel = 1;
  Map<String, dynamic>? caseStudyData;
  bool isLoading = true;
  String? userSubmission;
  TextEditingController _submissionController = TextEditingController();
  int? selectedLevel;
  bool _isPreviousSubmissionsExpanded = false;
  List<Map<String, dynamic>> previousSubmissions = [];
  late ConfettiController _confettiController;

  final Color primaryBlue = Color(0xFF1976D2);
  final Color lightBlue = Color(0xFF64B5F6);
  final Color veryLightBlue = Color(0xFFE3F2FD);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color accentBlue = Color(0xFF29B6F6);

  bool enableTieredVerification = true;
  String verificationMethod = 'api';

  @override
  void initState() {
    super.initState();
    _loadCaseStudyData();
    _checkUserProgress();
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
  }

  @override
  void dispose() {
    _submissionController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadCaseStudyData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('case_studies')
          .doc(widget.caseStudyId)
          .get();
      if (doc.exists) {
        setState(() {
          caseStudyData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Case study not found'),
              backgroundColor: primaryBlue),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading case study: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTitleAndDescription() {
    if (isLoading || caseStudyData == null) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caseStudyData!['title'] ?? 'Untitled Case Study',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          SizedBox(height: 8),
          Text(
            caseStudyData!['description'] ?? 'No description available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  void _showTitleAndDescriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get the screen size to make dialog responsive
        final screenSize = MediaQuery
            .of(context)
            .size;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min, // Important to prevent overflow
            children: [
              Icon(Icons.info, color: primaryBlue),
              SizedBox(width: 10),
              Flexible( // Wrap the Text in Flexible to allow it to wrap if needed
                child: Text(
                  'Case Study Details',
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          content: Container(
            width: screenSize.width * 0.8 < 400 ? screenSize.width * 0.8 : 400,
            // Responsive width
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.6, // Limit maximum height
            ),
            child: SingleChildScrollView(
              child: _buildTitleAndDescription(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: primaryBlue),
              child: Text('Close'),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 4,
          insetPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        );
      },
    );
  }

  Future<void> _checkUserProgress() async {
    var user = _auth.currentUser;
    if (user != null) {
      try {
        var progressDoc = await FirebaseFirestore.instance
            .collection('user_case_study_progress')
            .doc(user.uid)
            .collection('case_studies')
            .doc(widget.caseStudyId)
            .get();

        if (progressDoc.exists && progressDoc.data() != null) {
          var data = progressDoc.data()!;
          setState(() {
            currentLevel = data['currentLevel'] ?? 1;
            previousSubmissions = [];
            for (int i = 1; i < currentLevel; i++) {
              if (data.containsKey('level$i')) {
                var levelData = data['level$i'] as Map<String, dynamic>;
                double score = 0.0;
                if (levelData['score'] is int) {
                  score = (levelData['score'] as int).toDouble();
                } else if (levelData['score'] is double) {
                  score = levelData['score'] as double;
                }
                previousSubmissions.add({
                  'level': i,
                  'submission': levelData['submission'] ?? '',
                  'score': score,
                  'timestamp': levelData['timestamp'] as Timestamp? ??
                      Timestamp.now(),
                  'verificationMethod': levelData['verificationMethod'] ??
                      'api',
                });
              }
            }
          });
        }
      } catch (e) {
        print('Error checking user progress: $e');
      }
    }
  }

  Future<double> _simplifiedVerification(String submission, int level) async {
    if (caseStudyData == null) return 0.0;

    setState(() {
      verificationMethod = 'simplified';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Using simplified verification for quick response...'),
        backgroundColor: accentBlue,
        duration: Duration(seconds: 2),
      ),
    );

    // Prepare data for analysis
    String problem = caseStudyData!['description']?.toLowerCase() ?? '';
    String challengeText = caseStudyData!['challenges']?.toLowerCase() ?? '';
    String outcomeText = caseStudyData!['outcome']?.toLowerCase() ?? '';
    String domainText = caseStudyData!['domain']?.toLowerCase() ?? '';
    String skillsText = caseStudyData!['skills']?.toLowerCase() ?? '';

    String normalizedSubmission = submission.toLowerCase();
    double score = 0.0;

    // 1. Submission length analysis
    int wordCount = normalizedSubmission
        .split(' ')
        .length;
    double lengthScore = 0.0;
    if (wordCount < 20) {
      lengthScore = 2.0;
    } else if (wordCount < 50) {
      lengthScore = 3.0;
    } else if (wordCount < 100) {
      lengthScore = 4.0;
    } else if (wordCount < 200) {
      lengthScore = 5.0;
    } else {
      lengthScore = 6.0;
    }

    // 2. Content relevance - check for level-specific relevant keywords
    List<String> keyTerms = [];

    // Expanded common terms across all levels and fields
    List<String> commonTerms = [
      'ai',
      'machine learning',
      'algorithm',
      'code',
      'programming',
      'development',
      'review',
      'python',
      'java',
      'javascript',
      'errors',
      'debugging',
      'script',
      'system',
      'performance',
      'optimization',
      'technology',
      'software',
      'hardware',
      'testing',
      'validation',
      'research',
      'design',
      'implementation',
      'evaluation'
    ];

    // Domain-specific keyword sets (scalable for various fields)
    Map<String, List<String>> domainSpecificTerms = {
      'ai': [
        'ai',
        'artificial intelligence',
        'machine learning',
        'deep learning',
        'neural network',
        'algorithm',
        'training',
        'model',
        'prediction',
        'classification',
        'natural language',
        'computer vision',
        'reinforcement learning',
        'supervised',
        'unsupervised',
        'transformer',
        'llm',
        'language model',
        'embedding',
        'vector',
        'attention',
        'fine-tuning',
        'prompt',
        'inference',
        'generative',
        'discriminative',
        'bias',
        'ethics',
        'explainability',
        'gpt',
        'bert',
        'nlp',
        'computer vision',
        'cv',
        'robotics',
        'autonomous',
        'agent',
        'chatbot',
        'sentiment analysis',
        'speech recognition',
        'neural',
        'gan',
        'transfer learning'
      ],

      'software_development': [
        'code',
        'programming',
        'algorithm',
        'software',
        'development',
        'function',
        'method',
        'class',
        'object',
        'api',
        'framework',
        'library',
        'repository',
        'version control',
        'git',
        'debugging',
        'testing',
        'deployment',
        'scalability',
        'architecture',
        'microservices',
        'frontend',
        'backend',
        'full-stack',
        'database',
        'query',
        'optimization',
        'performance',
        'refactoring',
        'pattern',
        'design pattern',
        'devops',
        'cicd',
        'continuous integration',
        'security',
        'application',
        'scripting',
        'documentation',
        'specification',
        'requirements',
        'source control',
        'agile',
        'scrum',
        'kanban',
        'sprint',
        'technical debt',
        'code review',
        'pair programming',
        'sdk'
      ],
      'data_science': [
        'data',
        'analysis',
        'dataset',
        'model',
        'feature',
        'algorithm',
        'prediction',
        'regression',
        'classification',
        'clustering',
        'machine learning',
        'statistics',
        'visualization',
        'correlation',
        'causation',
        'accuracy',
        'precision',
        'recall',
        'f1-score',
        'neural network',
        'deep learning',
        'big data',
        'data cleaning',
        'data preprocessing',
        'dimensionality reduction',
        'overfitting',
        'underfitting',
        'cross-validation',
        'training data',
        'test data',
        'hypothesis',
        'data mining',
        'feature engineering',
        'data pipeline',
        'exploratory data analysis',
        'eda',
        'data visualization',
        'dashboard',
        'predictive modeling',
        'time series',
        'outlier'
      ],

      'cybersecurity': [
        'security',
        'threat',
        'vulnerability',
        'attack',
        'defense',
        'encryption',
        'firewall',
        'authentication',
        'authorization',
        'exploit',
        'malware',
        'virus',
        'phishing',
        'hacking',
        'penetration testing',
        'risk assessment',
        'compliance',
        'privacy',
        'data breach',
        'network security',
        'endpoint protection',
        'intrusion detection',
        'zero-day',
        'ransomware',
        'social engineering',
        'multi-factor',
        'cryptography',
        'hash',
        'vpn',
        'identity',
        'access management',
        'iam',
        'ssl',
        'tls',
        'certificate',
        'siem',
        'incident response',
        'forensics',
        'threat intelligence',
        'security audit'
      ],

      'business': [
        'strategy',
        'market',
        'customer',
        'revenue',
        'profit',
        'cost',
        'roi',
        'kpi',
        'stakeholder',
        'management',
        'leadership',
        'innovation',
        'competitive advantage',
        'business model',
        'value proposition',
        'marketing',
        'sales',
        'operations',
        'supply chain',
        'logistics',
        'finance',
        'accounting',
        'human resources',
        'organizational behavior',
        'change management',
        'project management',
        'agile',
        'investment',
        'growth',
        'scaling',
        'analytics',
        'customer acquisition',
        'retention',
        'churn',
        'conversion',
        'pricing',
        'budget',
        'forecast',
        'entrepreneur',
        'startup'
      ],
      'healthcare': [
        'patient',
        'diagnosis',
        'treatment',
        'clinical',
        'medical',
        'healthcare',
        'therapy',
        'doctor',
        'nurse',
        'hospital',
        'clinic',
        'disease',
        'symptom',
        'prescription',
        'medication',
        'surgery',
        'prevention',
        'rehabilitation',
        'chronic',
        'acute',
        'pathology',
        'radiology',
        'oncology',
        'cardiology',
        'neurology',
        'telemedicine',
        'electronic health record',
        'public health',
        'epidemiology',
        'wellness',
        'telehealth',
        'remote patient monitoring',
        'healthcare system',
        'insurance',
        'pharma',
        'biotechnology',
        'medical device',
        'clinical trial',
        'patient care'
      ],
      'technical': [
        'coding',
        'programming',
        'development',
        'engineering',
        'architecture',
        'design',
        'algorithm',
        'database',
        'network',
        'system',
        'infrastructure',
        'technology',
        'tool',
        'framework',
        'library',
        'platform',
        'language',
        'protocol',
        'standard',
        'specification',
        'api',
        'interface',
        'integration',
        'deployment',
        'automation',
        'frontend',
        'backend',
        'fullstack',
        'devops',
        'cloud',
        'microservices',
        'serverless',
        'containerization',
        'virtualization',
        'cybersecurity',
        'encryption',
        'authentication',
        'testing',
        'debugging',
        'optimization',
        'scaling',
        'versioning',
        'configuration'
      ],
      'analytical': [
        'analysis',
        'evaluation',
        'assessment',
        'calculation',
        'computation',
        'statistic',
        'data',
        'information',
        'insight',
        'pattern',
        'trend',
        'correlation',
        'causation',
        'inference',
        'deduction',
        'induction',
        'reasoning',
        'logic',
        'hypothesis',
        'theory',
        'methodology',
        'framework',
        'model',
        'simulation',
        'prediction',
        'forecasting',
        'critical thinking',
        'problem solving',
        'decision making',
        'quantitative',
        'qualitative',
        'diagnostics',
        'root cause',
        'metrics',
        'kpi',
        'benchmarking',
        'comparative analysis',
        'research',
        'investigation',
        'exploration',
        'discovery',
        'validation',
        'verification'
      ],
      'communication': [
        'communication',
        'presentation',
        'documentation',
        'report',
        'writing',
        'speaking',
        'listening',
        'feedback',
        'discussion',
        'dialogue',
        'conversation',
        'negotiation',
        'persuasion',
        'influence',
        'clarity',
        'conciseness',
        'articulation',
        'expression',
        'explanation',
        'instruction',
        'guidance',
        'briefing',
        'summary',
        'description',
        'storytelling',
        'narrative',
        'visualization',
        'illustration',
        'demonstration',
        'example',
        'public speaking',
        'facilitation',
        'moderation',
        'mediation',
        'translation',
        'interpretation',
        'technical writing',
        'copywriting',
        'content creation',
        'messaging',
        'branding'
      ],
      'management': [
        'management',
        'leadership',
        'coordination',
        'organization',
        'planning',
        'scheduling',
        'budgeting',
        'resource',
        'allocation',
        'delegation',
        'supervision',
        'control',
        'monitoring',
        'evaluation',
        'optimization',
        'efficiency',
        'effectiveness',
        'performance',
        'productivity',
        'quality',
        'improvement',
        'development',
        'change',
        'innovation',
        'strategy',
        'vision',
        'mission',
        'goal',
        'objective',
        'priority',
        'stakeholder',
        'team building',
        'motivation',
        'mentoring',
        'coaching',
        'feedback',
        'recognition',
        'conflict resolution',
        'decision making',
        'problem solving',
        'crisis management'
      ],
      'creative': [
        'creativity',
        'innovation',
        'design',
        'ideation',
        'brainstorming',
        'imagination',
        'originality',
        'novelty',
        'uniqueness',
        'vision',
        'perspective',
        'approach',
        'solution',
        'alternative',
        'possibility',
        'concept',
        'idea',
        'inspiration',
        'creation',
        'invention',
        'development',
        'transformation',
        'disruption',
        'revolution',
        'thinking outside the box',
        'lateral thinking',
        'divergent thinking',
        'creative problem solving',
        'artistic',
        'aesthetic',
        'visual',
        'spatial',
        'composition',
        'storytelling',
        'narrative',
        'experimentation',
        'exploration',
        'play',
        'curiosity',
        'risk-taking',
        'unconventional'
      ],
      'interpersonal': [
        'teamwork',
        'collaboration',
        'cooperation',
        'relationship',
        'interaction',
        'engagement',
        'participation',
        'contribution',
        'support',
        'assistance',
        'empathy',
        'understanding',
        'respect',
        'trust',
        'reliability',
        'dependability',
        'accountability',
        'responsibility',
        'leadership',
        'mentorship',
        'coaching',
        'guidance',
        'feedback',
        'conflict resolution',
        'negotiation',
        'mediation',
        'diplomacy',
        'tact',
        'persuasion',
        'influence',
        'motivation',
        'appreciation',
        'recognition',
        'cultural awareness',
        'diversity',
        'inclusion',
        'adaptability',
        'flexibility',
        'openness',
        'receptiveness',
        'active listening',
        'emotional intelligence'
      ],

      'education': [
        'learning',
        'teaching',
        'student',
        'education',
        'curriculum',
        'assessment',
        'pedagogy',
        'instruction',
        'classroom',
        'school',
        'course',
        'lecture',
        'assignment',
        'exam',
        'knowledge',
        'understanding',
        'skill',
        'competency',
        'e-learning',
        'blended learning',
        'personalized learning',
        'formative assessment',
        'summative assessment',
        'feedback',
        'educational technology',
        'differentiation',
        'scaffolding',
        'achievement',
        'student-centered',
        'lesson plan',
        'inquiry-based',
        'project-based',
        'rubric',
        'standards',
        'literacy',
        'numeracy',
        'k-12',
        'higher education',
        'mooc',
        'lms'
      ],

      'environmental': [
        'climate',
        'sustainability',
        'renewable',
        'carbon',
        'emissions',
        'green',
        'recycling',
        'conservation',
        'biodiversity',
        'ecosystem',
        'pollution',
        'waste management',
        'energy',
        'water',
        'agriculture',
        'deforestation',
        'greenhouse gas',
        'climate change',
        'global warming',
        'environmental impact',
        'natural resources',
        'fossil fuels',
        'solar',
        'wind',
        'hydro',
        'esg',
        'circular economy',
        'carbon footprint',
        'carbon neutral',
        'net zero'
      ],

      'finance': [
        'investment',
        'stocks',
        'bonds',
        'assets',
        'liabilities',
        'portfolio',
        'diversification',
        'risk',
        'return',
        'market',
        'trading',
        'broker',
        'dividend',
        'interest',
        'credit',
        'debt',
        'equity',
        'capital',
        'liquidity',
        'bankruptcy',
        'valuation',
        'hedge fund',
        'mutual fund',
        'etf',
        'option',
        'future',
        'derivative',
        'volatility',
        'fintech',
        'banking',
        'insurance',
        'taxation',
        'accounting',
        'audit',
        'compliance',
        'retirement'
      ]
      // Add more domains as needed (e.g., 'blockchain', 'iot', 'cloud computing')
    };

    // Level-specific terms (expanded for each level)
    switch (level) {
      case 1: // Understanding phase
        keyTerms = [
          'problem',
          'identify',
          'understand',
          'challenge',
          'issue',
          'summary',
          'statement',
          'background',
          'context',
          'situation',
          'scenario',
          'requirement',
          'need',
          'scope',
          'objective',
          'goal',
          'purpose',
          'stakeholder',
          'constraint',
          'limitation',
          'assumption',
          'question',
          'inquiry',
          'exploration',
          'investigation',
          'analysis',
          'examination',
          'overview',
          'description',
          'definition',
          'specification',
          'characterization',
          'factor',
          'cause',
          'symptom',
          'indication',
          'consequence',
          'impact',
          'effect',
          'significance',
          'complexity',
          'difficulty',
          'obstacle',
          'barrier',
          'impediment',
          'roadblock',
          'hurdle',
          'pain point',
          'bottleneck',
          'gap',
          'deficiency',
          'shortcoming',
          'weakness',
          'vulnerability'
        ];
        break;
      case 2: // Data collection
        keyTerms = [
          'data',
          'dataset',
          'collection',
          'analysis',
          'research',
          'insight',
          'information',
          'source',
          'gathering',
          'measurement',
          'metric',
          'indicator',
          'statistic',
          'survey',
          'interview',
          'observation',
          'experiment',
          'sampling',
          'questionnaire',
          'focus group',
          'primary data',
          'secondary data',
          'qualitative',
          'quantitative',
          'correlation',
          'variable',
          'parameter',
          'attribute',
          'feature',
          'property',
          'characteristic',
          'trend',
          'pattern',
          'anomaly',
          'outlier',
          'distribution',
          'frequency',
          'range',
          'validation',
          'verification',
          'reliability',
          'validity',
          'accuracy',
          'precision',
          'data mining',
          'scraping',
          'extraction',
          'cleansing',
          'preprocessing',
          'transformation',
          'aggregation',
          'integration',
          'visualization',
          'chart',
          'graph',
          'dashboard',
          'report'
        ];
        break;
      case 3: // Solution
        keyTerms = [
          'solution',
          'approach',
          'method',
          'solve',
          'implement',
          'proposal',
          'resolve',
          'strategy',
          'tactic',
          'technique',
          'procedure',
          'process',
          'system',
          'framework',
          'model',
          'design',
          'prototype',
          'proof of concept',
          'pilot',
          'test',
          'experiment',
          'innovation',
          'creativity',
          'invention',
          'development',
          'construction',
          'creation',
          'alternative',
          'option',
          'choice',
          'decision',
          'selection',
          'priority',
          'trade-off',
          'feasibility',
          'viability',
          'practicality',
          'cost-benefit',
          'risk-reward',
          'value',
          'efficiency',
          'effectiveness',
          'optimization',
          'improvement',
          'enhancement',
          'upgrade',
          'algorithm',
          'tool',
          'technology',
          'platform',
          'software',
          'hardware',
          'infrastructure',
          'methodology',
          'blueprint',
          'roadmap',
          'workflow',
          'pipeline',
          'architecture',
          'topology'
        ];
        break;
      case 4: // Final report
        keyTerms = [
          'conclusion',
          'result',
          'outcome',
          'summary',
          'recommendation',
          'report',
          'analysis',
          'finding',
          'discovery',
          'lesson',
          'learning',
          'insight',
          'implication',
          'application',
          'significance',
          'importance',
          'relevance',
          'impact',
          'effect',
          'consequence',
          'benefit',
          'value',
          'roi',
          'success',
          'achievement',
          'accomplishment',
          'failure',
          'limitation',
          'constraint',
          'challenge',
          'obstacle',
          'difficulty',
          'problem',
          'issue',
          'concern',
          'future',
          'next step',
          'recommendation',
          'suggestion',
          'advice',
          'guidance',
          'direction',
          'strategy',
          'plan',
          'roadmap',
          'vision',
          'mission',
          'goal',
          'objective',
          'target',
          'evaluation',
          'assessment',
          'measurement',
          'metric',
          'kpi',
          'benchmark',
          'standard',
          'comparison',
          'reference',
          'baseline',
          'progress',
          'growth',
          'improvement',
          'development'
        ];
        break;
    }

    // Add common terms
    keyTerms.addAll(commonTerms);

    // Add domain-specific terms based on domainText
    domainSpecificTerms.forEach((domain, terms) {
      if (domainText.contains(domain)) {
        keyTerms.addAll(terms);
      }
    });

    // Add terms from domainText and skillsText
    keyTerms.addAll(domainText.split(' ').where((term) => term.isNotEmpty));
    keyTerms.addAll(
        skillsText.split(',').map((s) => s.trim()).where((term) => term
            .isNotEmpty));

    // Remove duplicates and empty strings
    keyTerms = keyTerms.where((term) => term.isNotEmpty).toSet().toList();

    // Count matching keywords
    int matches = keyTerms
        .where((term) => normalizedSubmission.contains(term))
        .length;
    double keywordRatio = keyTerms.isEmpty ? 0 : matches / keyTerms.length;
    double relevanceScore = keywordRatio * 7.0; // Scale to max 7 points

    // 3. Problem statement matching (expanded for all levels)
    double contextScore = 0.0;
    if (level == 1) {
      int problemMatches = problem
          .split(' ')
          .where((word) => word.length > 4)
          .where((word) => normalizedSubmission.contains(word))
          .length;
      double problemMatchRatio = problem.isEmpty
          ? 0
          : problemMatches / problem
          .split(' ')
          .where((word) => word.length > 4)
          .length;
      contextScore = problemMatchRatio * 3.0;
    } else if (level == 2) {
      // Check relevance to data-related terms in problem or challenges
      int dataMatches = problem
          .split(' ')
          .where((word) => word.length > 4 && keyTerms.contains(word))
          .where((word) => normalizedSubmission.contains(word))
          .length;
      double dataMatchRatio = problem.isEmpty
          ? 0
          : dataMatches / problem
          .split(' ')
          .where((word) => word.length > 4)
          .length;
      contextScore = dataMatchRatio * 3.0;
    } else if (level == 3) {
      int challengeMatches = challengeText
          .split(' ')
          .where((word) => word.length > 4)
          .where((word) => normalizedSubmission.contains(word))
          .length;
      double challengeMatchRatio = challengeText.isEmpty
          ? 0
          : challengeMatches / challengeText
          .split(' ')
          .where((word) => word.length > 4)
          .length;
      contextScore = challengeMatchRatio * 3.0;
    } else if (level == 4) {
      int challengeMatches = challengeText
          .split(' ')
          .where((word) => word.length > 4)
          .where((word) => normalizedSubmission.contains(word))
          .length;
      int outcomeMatches = outcomeText
          .split(' ')
          .where((word) => word.length > 4)
          .where((word) => normalizedSubmission.contains(word))
          .length;
      double challengeMatchRatio = challengeText.isEmpty
          ? 0
          : challengeMatches / challengeText
          .split(' ')
          .where((word) => word.length > 4)
          .length;
      double outcomeMatchRatio = outcomeText.isEmpty
          ? 0
          : outcomeMatches / outcomeText
          .split(' ')
          .where((word) => word.length > 4)
          .length;
      contextScore = ((challengeMatchRatio + outcomeMatchRatio) / 2) * 3.0;
    }

    // 4. Structure analysis (unchanged but could be expanded)
    double structureScore = 0.0;
    if (normalizedSubmission.contains('introduction') ||
        normalizedSubmission.contains('problem statement')) {
      structureScore += 0.5;
    }
    if (normalizedSubmission.contains('solution') ||
        normalizedSubmission.contains('approach')) {
      structureScore += 0.5;
    }
    if (normalizedSubmission.contains('conclusion') ||
        normalizedSubmission.contains('summary')) {
      structureScore += 0.5;
    }
    int bulletPoints = '•'
        .allMatches(normalizedSubmission)
        .length;
    int numberedPoints = RegExp(r'\d+\.')
        .allMatches(normalizedSubmission)
        .length;
    if (bulletPoints > 0 || numberedPoints > 0) {
      structureScore += 0.5;
    }

    // Combine all scores
    score = lengthScore + relevanceScore + contextScore + structureScore;
    score = score.clamp(0.0, 10.0);

    print('Simplified verification results:');
    print('- Length score: $lengthScore (from $wordCount words)');
    print('- Relevance score: $relevanceScore (matched $matches of ${keyTerms
        .length} key terms)');
    print('- Context score: $contextScore');
    print('- Structure score: $structureScore');
    print('- Total score: $score');

    return score;
  }

  Future<double> _verifySubmission(String submission, int level) async {
    if (caseStudyData == null) return 0.0;

    if (enableTieredVerification) {
      double simplifiedScore = await _simplifiedVerification(submission, level);
      if (simplifiedScore < 3.0 || simplifiedScore > 8.0) {
        print('Using simplified score: $simplifiedScore (bypassing API)');
        return simplifiedScore;
      }
      print('Borderline score ($simplifiedScore), using API verification');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Borderline submission, using detailed verification...'),
          backgroundColor: primaryBlue,
        ),
      );
    }

    if (submission.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verifying your detailed submission...'),
          backgroundColor: primaryBlue,
        ),
      );
    }

    setState(() {
      verificationMethod = 'api';
    });

    String prompt = '';
    switch (level) {
      case 1:
        prompt =
        'Evaluate this summary against the problem statement: "${caseStudyData!['description'] ??
            ''}"\n'
            'User submission: "$submission"\n'
            'Assign a score out of 10 based on relevance and content. '
            'Give partial credit (at least 5/10) if the submission addresses at least 50% of the problem statement, '
            'such as mentioning error identification or Python scripts in an AI-based context. '
            'Award higher scores for detail and examples. '
            'Return only the numeric score (e.g., 5.5 or 8.0) without additional text.';
        break;
      case 2:
        prompt =
        'Evaluate this explanation of datasets or research insights for: "${caseStudyData!['description'] ??
            ''}"\n'
            'User submission: "$submission"\n'
            'Assign a score out of 10, giving at least 5/10 if it partially relates to the problem (e.g., describes data for identifying Python errors). '
            'Award higher scores for detailed explanations or examples. '
            'Return only the numeric score (e.g., 5.0).';
        break;
      case 3:
        prompt =
        'Evaluate if this is a valid solution proposal for: "${caseStudyData!['description'] ??
            ''}"\n'
            'User submission: "$submission"\n'
            'Assign a score out of 10, giving at least 5/10 if it partially addresses the problem (e.g., suggests a method for error detection). '
            'Award higher scores for feasibility and detail. '
            'Return only the numeric score (e.g., 6.0).';
        break;
      case 4:
        prompt =
        'Evaluate if this is a complete case study report for: "${caseStudyData!['description'] ??
            ''}"\n'
            'User submission: "$submission"\n'
            'Assign a score out of 10, giving at least 5/10 if it partially covers the problem (e.g., includes some analysis or solution). '
            'Award higher scores for completeness and quality. '
            'Return only the numeric score (e.g., 5.5).';
        break;
    }

    try {
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      final result = jsonDecode(response.body);
      String responseText = result['candidates'][0]['content']['parts'][0]['text'];

      print('Gemini API Response for Level $level: $responseText');

      RegExp scorePattern = RegExp(r'\d+\.?\d*');
      Match? match = scorePattern.firstMatch(responseText);
      double score = match != null ? double.parse(match.group(0)!) : 0.0;

      return score.clamp(0.0, 10.0);
    } catch (e) {
      print('Verification API error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification service unavailable: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // If API fails, fall back to simplified verification
      return await _simplifiedVerification(submission, level);
    }
  }



  Future<Map<String, dynamic>?> _getStudentProfile(String uid) async {
    try {
      var profileDoc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(uid)
          .get();
      if (profileDoc.exists) {
        return profileDoc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching student profile: $e');
      return null;
    }
  }

  void _showSuccessDialog(double score) {
    // Start confetti animation
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return Stack(
          children: [
            // Confetti effect on top of the dialog
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.2,
                shouldLoop: false,
                colors: [
                  Colors.blue,
                  Colors.cyan,
                  Colors.lightBlue,
                  Colors.lightBlueAccent,
                  Colors.white,
                ],
              ),
            ),

            AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Level Passed!',
                    style: TextStyle(
                      color: darkBlue,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Congratulations! You have successfully completed Level ${selectedLevel ??
                        currentLevel}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: veryLightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Your Score:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${score.toStringAsFixed(1)}/10',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        verificationMethod == 'simplified' ?
                        Icons.speed : Icons.schema,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Verified using ${verificationMethod == 'simplified' ?
                        'simplified scoring' : 'Gemini API'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    currentLevel > 4
                        ? 'You have completed all levels! You can now claim your certificate.'
                        : 'You can now continue to Level $currentLevel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: primaryBlue,
                  ),
                  child: Text('Continue', style: TextStyle(fontSize: 16)),
                ),
                if (currentLevel > 4)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _navigateToCertificate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                        'Get Certificate', style: TextStyle(fontSize: 16)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAnswer() async {
    if (userSubmission == null || userSubmission!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your submission'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    double score = await _verifySubmission(
        userSubmission!, selectedLevel ?? currentLevel);

    var user = _auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    Map<String, dynamic>? profile = await _getStudentProfile(user.uid);
    String fullName = profile?['fullName'] ?? 'Unknown';
    String phoneNumber = profile?['phoneNumber'] ?? 'Not provided';

    if (score >= 5.0) {
      // Store the submission with profile info
      await FirebaseFirestore.instance
          .collection('user_case_study_progress')
          .doc(user.uid)
          .collection('case_studies')
          .doc(widget.caseStudyId)
          .set({
        'currentLevel': currentLevel + 1,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'level$currentLevel': {
          'submission': userSubmission,
          'timestamp': FieldValue.serverTimestamp(),
          'verified': true,
          'score': score,
          'apiFailed': false,
          'verificationMethod': verificationMethod,
        },
      }, SetOptions(merge: true));

      // Update local state
      setState(() {
        // Add to previous submissions
        previousSubmissions.add({
          'level': currentLevel,
          'submission': userSubmission,
          'score': score, // This is already a double from _verifySubmission
          'timestamp': Timestamp.now(),
          'verificationMethod': verificationMethod,
        });

        currentLevel++;
        userSubmission = null;
        _submissionController.clear();
        selectedLevel = null;

        // Show success dialog with confetti
        isLoading = false;
        _showSuccessDialog(score);
      });
    } else {
      // Store the failed submission
      if (score > 0.0) {
        await FirebaseFirestore.instance
            .collection('user_case_study_progress')
            .doc(user.uid)
            .collection('case_studies')
            .doc(widget.caseStudyId)
            .set({
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'level${selectedLevel ?? currentLevel}': {
            'submission': userSubmission,
            'timestamp': FieldValue.serverTimestamp(),
            'verified': false,
            'score': score,
            'apiFailed': score < 5.0 && score > 0.0,
            'verificationMethod': verificationMethod,
          },
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission score (${score.toStringAsFixed(
              1)}/10) is below 5. Please improve and try again.'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.orange[800],
          action: SnackBarAction(
            label: 'See Hints',
            textColor: Colors.white,
            onPressed: _showHints,
          ),
        ),
      );
      setState(() => isLoading = false);
    }
  }

  void _showHints() {
    if (caseStudyData == null || !caseStudyData!.containsKey('hints')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hints available for this case study'),
          backgroundColor: primaryBlue,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 10),
                Text('Hints', style: TextStyle(color: darkBlue)),
              ],
            ),
            content: Text(caseStudyData!['hints'] ?? 'No hints available'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: primaryBlue,
                ),
                child: Text('OK'),
              ),
            ],
            backgroundColor: Colors.white,
            elevation: 4,
          ),
    );
  }

  void _showVerificationInfo() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Submission Verification',
              style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First tier - simplified verification
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: veryLightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speed, color: primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Quick Analysis',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('• Length and detail'),
                        Text('• Relevant keywords'),
                        Text('• Problem coverage'),
                        Text('• Structure'),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Second tier - API verification
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: veryLightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                                Icons.psychology, color: primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AI Evaluation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('For borderline submissions'),
                        SizedBox(height: 4),
                        Text('• Level-specific scoring'),
                        Text('• Minimum 5/10 to advance'),
                      ],
                    ),
                  ),

                  SizedBox(height: 12),
                  Text(
                    'A score of 5/10 or higher advances you to the next level.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: enableTieredVerification,
                    onChanged: (value) {
                      setState(() {
                        enableTieredVerification = value;
                        Navigator.pop(context);
                        // Reopen the dialog to reflect the change
                        Future.delayed(
                            Duration(milliseconds: 300), _showVerificationInfo);
                      });
                    },
                    activeColor: primaryBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text(
                    enableTieredVerification ? 'On' : 'Off',
                    style: TextStyle(
                      color: enableTieredVerification ? primaryBlue : Colors
                          .grey,
                      fontSize: 12,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBlue,
                    ),
                    child: Text('Close'),
                  ),
                ],
              ),
            ],
            backgroundColor: Colors.white,
            elevation: 4,
          ),
    );
  }

  Widget _buildVerificationStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
              fontWeight: FontWeight.bold, color: darkBlue, fontSize: 13)),
          Text(description, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _navigateToMentorHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MentorPage()),
    );
  }

  void _navigateToCertificate() {
    var user = _auth.currentUser;
    if (user != null && caseStudyData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CertificatePage(
                caseStudyId: widget.caseStudyId,
                userId: user.uid,
                problemTitle: caseStudyData!['title'] ?? 'Untitled Case Study',
                problemDescription: caseStudyData!['description'] ??
                    'No description available',
                skills: caseStudyData!['skills'] ?? '',
                domain: caseStudyData!['domain'] ?? '',
                outcome: caseStudyData!['outcome'] ?? '',
              ),
        ),
      );
    }
  }

  Widget _buildPreviousSubmissions() {
    if (previousSubmissions.isEmpty) {
      return SizedBox.shrink();
    }

    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: EdgeInsets.all(0),
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _isPreviousSubmissionsExpanded = !_isPreviousSubmissionsExpanded;
        });
      },
      children: [
        ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(
                'Previous Submissions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              leading: Icon(
                Icons.history,
                color: primaryBlue,
              ),
            );
          },
          body: Container(
            height: 300, // Fixed height to prevent overflow
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: previousSubmissions.length,
              itemBuilder: (context, index) {
                var submission = previousSubmissions[index];
                String verMethod = submission['verificationMethod'] ?? 'api';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: lightBlue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Level ${submission['level']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.amber,
                                      size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    '${(submission['score'] as double)
                                        .toStringAsFixed(1)}/10',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Divider(color: Colors.grey[300]),
                          Text(
                            submission['submission'] as String,
                            style: TextStyle(
                              fontSize: 14,
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Submitted: ${_formatTimestamp(
                                    submission['timestamp'] as Timestamp)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    verMethod == 'simplified'
                                        ? Icons.speed
                                        : Icons.psychology,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    verMethod == 'simplified'
                                        ? 'Fast verify'
                                        : 'AI verify',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          isExpanded: _isPreviousSubmissionsExpanded,
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute
        .toString().padLeft(2, '0')}';
  }

  Widget _buildLevelContent() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }
    if (caseStudyData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Case study data not available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (selectedLevel == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previousSubmissions.isNotEmpty) _buildPreviousSubmissions(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Case Study Roadmap',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildRoadmapTile(
                    1, 'Understanding the Problem',
                    'Summarize the problem statement'),
                _buildRoadmapTile(
                    2, 'Data Collection & Analysis',
                    'Explain datasets or insights'),
                _buildRoadmapTile(3, 'Solution Proposal', 'Propose a solution'),
                _buildRoadmapTile(
                    4, 'Final Report Submission', 'Submit a full report'),
                _buildRoadmapTile(
                    5, 'Certificate', 'Claim your certificate',
                    isCertificate: true),
                if (caseStudyData!.containsKey('related') &&
                    caseStudyData!['related'] != null)
                  _buildRelatedResourcesTile(caseStudyData!['related']),

                // Tiered verification info card
                if (enableTieredVerification)
                  Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 16),
                    color: veryLightBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: lightBlue, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speed, color: primaryBlue),
                              SizedBox(width: 8),
                              Text(
                                'Tiered Verification Enabled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your submissions will be evaluated using our tiered verification system:',
                            style: TextStyle(color: darkBlue),
                          ),
                          SizedBox(height: 4),
                          Text(
                              '• Fast assessment for clearly passing/failing submissions'),
                          Text('• In-depth AI evaluation for borderline cases'),
                          Text('• Reduced response time for most submissions'),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(Icons.info_outline, size: 16),
                                label: Text('Learn More'),
                                onPressed: _showVerificationInfo,
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Check if the selected level is already completed
    bool isLevelCompleted = selectedLevel! < currentLevel;

    switch (selectedLevel) {
      case 1:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add level completion notification at the top
              if (isLevelCompleted)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level 1 Already Completed!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You\'ve already passed this level. You can review or resubmit if you wish.',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Level 1: Understanding the Problem',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: veryLightBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Problem Statement:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(caseStudyData!['description'] ??
                        'No description available'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Write a summary of this problem:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _submissionController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  hintText: 'Your summary...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (value) => userSubmission = value,
              ),
              if (enableTieredVerification)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: accentBlue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tiered verification enabled for faster feedback',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              // Add padding at the bottom to ensure content isn't hidden behind the submit button
              SizedBox(height: 80),
            ],
          ),
        );
      case 2:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add level completion notification at the top
              if (isLevelCompleted)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level 2 Already Completed!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You\'ve already passed this level. You can review or resubmit if you wish.',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Level 2: Data Collection & Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: veryLightBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Explain the dataset or research insights you would use for solve the problem',
                  style: TextStyle(
                    color: darkBlue,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Describe your approach:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _submissionController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  hintText: 'Describe the datasets and research insights...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (value) => userSubmission = value,
              ),
              if (enableTieredVerification)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: accentBlue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tiered verification enabled for faster feedback',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              // Add padding at the bottom to ensure content isn't hidden behind the submit button
              SizedBox(height: 80),
            ],
          ),
        );
      case 3:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add level completion notification at the top
              if (isLevelCompleted)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level 3 Already Completed!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You\'ve already passed this level. You can review or resubmit if you wish.',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Level 3: Solution Proposal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: veryLightBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenge:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      caseStudyData!['challenges'] ??
                          'Create a solution for the case study problem.',
                      style: TextStyle(
                        color: darkBlue,
                      ),
                    ),
                    if (caseStudyData!.containsKey('outcome') &&
                        caseStudyData!['outcome'] != null) ...[
                      SizedBox(height: 12),
                      Text(
                        'Expected Outcome:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        caseStudyData!['outcome'],
                        style: TextStyle(
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Propose your solution:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _submissionController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  hintText: 'Describe your proposed solution...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (value) => userSubmission = value,
              ),
              if (enableTieredVerification)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: accentBlue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tiered verification enabled for faster feedback',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              // Add padding at the bottom to ensure content isn't hidden behind the submit button
              SizedBox(height: 80),
            ],
          ),
        );

      case 4:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add level completion notification at the top
              if (isLevelCompleted)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level 4 Already Completed!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You\'ve already passed this level. You can review or resubmit if you wish.',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Level 4: Final Report Submission',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: veryLightBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your case study with a full report that includes:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Problem statement summary\n'
                          '• Data collection and analysis methods\n'
                          '• Proposed solution with implementation details\n'
                          '• Expected outcomes and metrics\n'
                          '• Challenges and future improvements',
                      style: TextStyle(
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Write your report:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _submissionController,
                maxLines: 10,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  hintText: 'Write your full case study report here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (value) => userSubmission = value,
              ),
              if (userSubmission != null && userSubmission!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Card(
                    elevation: 0,
                    color: Colors.green[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.green[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Report prepared for submission (${userSubmission!
                                  .length} characters)',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() => userSubmission = null);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (enableTieredVerification)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: accentBlue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tiered verification enabled for faster feedback',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              // Add padding at the bottom to ensure content isn't hidden behind the submit button
              SizedBox(height: 80),
            ],
          ),
        );
      default:
        return Center(child: Text('Invalid selection'));
    }
  }

  Widget _buildRoadmapTile(int level, String title, String subtitle,
      {bool isCertificate = false}) {
    bool isUnlocked = isCertificate ? currentLevel > 4 : level <= currentLevel;
    bool isCurrentLevel = !isCertificate && level == currentLevel;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      color: isCurrentLevel ? veryLightBlue : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentLevel
            ? BorderSide(color: primaryBlue, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          child: Text(
            isCertificate ? 'C' : '$level',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: isUnlocked
              ? isCurrentLevel ? primaryBlue : Colors.green
              : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isCurrentLevel ? FontWeight.bold : FontWeight.normal,
            color: isCurrentLevel ? darkBlue : Colors.black87,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: isUnlocked
                ? isCurrentLevel ? veryLightBlue : Colors.green[50]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked
                  ? isCurrentLevel ? primaryBlue : Colors.green
                  : Colors.grey,
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(8),
          child: Icon(
            isUnlocked ? Icons.lock_open : Icons.lock,
            color: isUnlocked
                ? isCurrentLevel ? primaryBlue : Colors.green
                : Colors.grey,
            size: 20,
          ),
        ),
        onTap: isUnlocked
            ? () {
          setState(() {
            if (isCertificate) {
              _navigateToCertificate();
            } else {
              selectedLevel = level;
              _submissionController.clear();
              userSubmission = null;
            }
          });
        }
            : null,
      ),
    );
  }

  Widget _buildRelatedResourcesTile(String relatedUrl) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          child: Icon(
            Icons.link,
            color: Colors.white,
          ),
          backgroundColor: Colors.amber[600],
        ),
        title: Text(
          'Related Resources',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('Explore additional learning materials'),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.amber[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.open_in_new,
            color: Colors.amber[800],
            size: 20,
          ),
        ),
        onTap: () {
          // Handle opening URL (implement URL launching)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening: $relatedUrl'),
              backgroundColor: primaryBlue,
            ),
          );
          // You would typically use url_launcher package here
          // launchUrl(Uri.parse(relatedUrl));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: primaryBlue,
          secondary: accentBlue,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            caseStudyData != null
                ? caseStudyData!['title'] ?? 'Case Study'
                : 'Loading...',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
          ),
          actions: [
            if (selectedLevel != null)
              IconButton(
                icon: Icon(Icons.arrow_back),
                tooltip: 'Back to roadmap',
                onPressed: () {
                  setState(() {
                    selectedLevel = null;
                    userSubmission = null;
                    _submissionController.clear();
                  });
                },
              ),
            if (caseStudyData != null && caseStudyData!.containsKey('hints') &&
                selectedLevel != null)
              IconButton(
                icon: Icon(Icons.lightbulb_outline),
                tooltip: 'View hints',
                onPressed: _showHints,
              ),
            IconButton(
              icon: Icon(
                enableTieredVerification ? Icons.speed : Icons.psychology,
                color: Colors.white,
              ),
              tooltip: enableTieredVerification
                  ? 'Tiered Verification On'
                  : 'Tiered Verification Off',
              onPressed: () {
                setState(() {
                  enableTieredVerification = !enableTieredVerification;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      enableTieredVerification
                          ? 'Tiered verification enabled: Fast assessment for clear cases'
                          : 'Tiered verification disabled: All submissions use Gemini API',
                    ),
                    duration: Duration(seconds: 3),
                    backgroundColor: enableTieredVerification
                        ? primaryBlue
                        : Colors.grey[700],
                    action: SnackBarAction(
                      label: 'Learn More',
                      textColor: Colors.white,
                      onPressed: _showVerificationInfo,
                    ),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'verify') {
                  _showVerificationInfo();
                } else if (value == 'mentor') {
                  _navigateToMentorHelp(); // Navigate to MentorHelpPage
                } else if (value == 'domain') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Domain: ${caseStudyData?['domain'] ??
                          'Not specified'}'),
                      backgroundColor: primaryBlue,
                    ),
                  );
                } else if (value == 'skills') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Skills: ${caseStudyData?['skills'] ??
                          'Not specified'}'),
                      backgroundColor: primaryBlue,
                    ),
                  );
                } else if (value == 'tiered') {
                  setState(() {
                    enableTieredVerification = !enableTieredVerification;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        enableTieredVerification
                            ? 'Tiered verification enabled'
                            : 'Tiered verification disabled',
                      ),
                      backgroundColor: primaryBlue,
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'verify',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.verified_user, color: primaryBlue),
                    title: Text('How We Verify Answers'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'mentor',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.support_agent, color: primaryBlue),
                    title: Text('Ask Mentor Help'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'domain',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.domain, color: primaryBlue),
                    title: Text('View Domain'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'skills',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.build, color: primaryBlue),
                    title: Text('View Skills'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'tiered',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      enableTieredVerification ? Icons.speed : Icons.psychology,
                      color: primaryBlue,
                    ),
                    title: Text(
                      enableTieredVerification
                          ? 'Disable Tiered Verification'
                          : 'Enable Tiered Verification',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        Row(
                          children: [
                            if (enableTieredVerification)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Tooltip(
                                  message: 'Tiered verification enabled',
                                  child: Icon(
                                    Icons.speed,
                                    color: accentBlue,
                                    size: 16,
                                  ),
                                ),
                              ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: currentLevel > 4
                                    ? Colors.green
                                    : primaryBlue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Level $currentLevel/4',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: currentLevel / 4,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          currentLevel > 4 ? Colors.green : primaryBlue,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Expanded(child: _buildLevelContent()),
              if (selectedLevel != null && selectedLevel! <= 4)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitAnswer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              strokeWidth: 2,
                            ),
                          ),
                        if (isLoading) SizedBox(width: 10),
                        Text(
                          isLoading ? 'Verifying...' : 'Submit Answer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (enableTieredVerification && !isLoading)
                          Row(
                            children: [
                              SizedBox(width: 8),
                              Icon(Icons.speed, size: 16),
                            ],
                          ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      minimumSize: Size(double.infinity, 54),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showTitleAndDescriptionDialog,
          backgroundColor: primaryBlue,
          child: Icon(Icons.info, color: Colors.white),
          tooltip: 'View Case Study Details',
        ),
      ),
    );
  }
}
