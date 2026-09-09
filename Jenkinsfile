pipeline {
  agent { label 'docker' }

  options {
    withFolderProperties()
  }

  stages {
    stage('Lint') {
      steps {
        sh 'make lint'
      }
    }
  }
}
