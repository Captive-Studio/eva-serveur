# frozen_string_literal: true

require 'rails_helper'

describe 'Admin - Evaluation', type: :feature do
  before { Bullet.enable = false }

  after { Bullet.enable = true }

  let(:role) { 'admin' }
  let(:mon_compte) { create :compte, role: role }
  let(:parcours_type) { create :parcours_type, :competences_de_base }
  let(:ma_campagne) do
    create :campagne, compte: mon_compte, libelle: 'Paris 2019', code: 'PARIS2019',
                      parcours_type: parcours_type
  end

  describe '#index' do
    before do
      connecte(mon_compte)
      visit admin_evaluations_path
    end

    it "n'affiche pas les statistiques" do
      expect(page).not_to have_content('Statistiques')
    end

    context 'en tant que superadmin' do
      let(:role) { 'superadmin' }

      it 'affiche les statistiques' do
        expect(page).to have_content('Statistiques')
      end
    end
  end

  describe '#show' do
    before { connecte(mon_compte) }

    context 'situation plan de la ville' do
      let!(:mon_evaluation_plan_de_la_ville) { create :evaluation, campagne: campagne }
      let!(:partie) do
        create :partie, situation: plan_de_la_ville, evaluation: mon_evaluation_plan_de_la_ville
      end

      # evaluation avec positionnement
      let(:bienvenue) { create(:situation_bienvenue, questionnaire: questionnaire) }
      let(:plan_de_la_ville) { create(:situation_plan_de_la_ville) }
      let(:campagne) do
        create :campagne, compte: Compte.first, parcours_type: parcours_type
      end

      before do
        campagne.situations_configurations.create situation: plan_de_la_ville
      end

      context 'quand elle est terminée' do
        before do
          create :evenement_demarrage, partie: partie
          create :evenement_fin_situation, partie: partie
          visit admin_evaluation_path(mon_evaluation_plan_de_la_ville)
        end

        it 'affiche une restitution' do
          expect(page).to have_content 'Compétences numériques'
        end
      end

      context "quand elle n'est pas terminée" do
        before do
          create :evenement_demarrage, partie: partie
        end

        it "n'affiche pas de restitution si la situation n'est par terminée" do
          visit admin_evaluation_path(mon_evaluation_plan_de_la_ville)
          expect(page).not_to have_content 'Compétences numériques'
        end
      end
    end

    context 'situation bienvenue' do
      let!(:mon_evaluation_bienvenue) { create :evaluation, campagne: campagne_bienvenue }
      let!(:partie_bienvenue) do
        create :partie, situation: bienvenue, evaluation: mon_evaluation_bienvenue
      end
      let!(:evenement_bienvenue) { create :evenement_demarrage, partie: partie_bienvenue }
      let(:questionnaire) { create :questionnaire, questions: [] }

      # evaluation avec positionnement
      let(:bienvenue) { create(:situation_bienvenue, questionnaire: questionnaire) }
      let(:plan_de_la_ville) { create(:situation_plan_de_la_ville) }
      let(:campagne_bienvenue) do
        create :campagne, compte: Compte.first, parcours_type: parcours_type
      end
      let(:quetionnaire_auto) { create :questionnaire, :sociodemographique_autopositionnement }

      context 'sans autopositionnement' do
        before do
          campagne_bienvenue.situations_configurations.create situation: bienvenue
        end

        it 'affiche les données données sociodémographqiues par défaut' do
          visit admin_evaluation_path(mon_evaluation_bienvenue)
          expect(page).to have_content 'Situation'
          expect(page).to have_content 'Scolarité'
          expect(page).not_to have_content 'auto-positionnement'
          expect(page).to have_content 'Roger'
        end
      end

      context 'avec autopositionnement' do
        before do
          campagne_bienvenue.situations_configurations.create situation: bienvenue,
                                                              questionnaire: quetionnaire_auto
        end

        it "affiche l'auto_positionnement en plus" do
          visit admin_evaluation_path(mon_evaluation_bienvenue)
          expect(page).to have_content 'auto-positionnement'
          expect(page).to have_content 'Roger'
        end
      end
    end

    context 'Rôle admin' do
      let(:role) { 'admin' }
      let!(:mon_evaluation) do
        create :evaluation,
               campagne: ma_campagne,
               created_at: 3.days.ago,
               synthese_competences_de_base: :ni_ni
      end
      let(:situation) { build(:situation_inventaire) }
      let!(:partie) { create :partie, situation: situation, evaluation: mon_evaluation }
      let!(:evenement) { create :evenement_demarrage, partie: partie }
      let(:restitution) { Restitution::Inventaire.new(ma_campagne, [evenement]) }

      it "n'affiche pas les situations jouées" do
        visit admin_evaluation_path(mon_evaluation)
        expect(page).not_to have_content 'Selection Situation'
        expect(page).not_to have_content 'Inventaire'
      end

      it 'restitution sans auto_positionnement' do
        visit admin_evaluation_path(mon_evaluation)
        expect(page).not_to have_content 'auto-positionnement'
        expect(page).to have_content 'Roger'
      end

      it 'restitution sans plan de la ville' do
        visit admin_evaluation_path(mon_evaluation)
        expect(page).not_to have_content 'Compétences numériques'
      end

      describe 'en moquant restitution_globale :' do
        let(:restitution_globale) do
          double(Restitution::Globale,
                 date: DateTime.now,
                 utilisateur: 'Roger',
                 efficience: 5,
                 restitutions: [restitution])
        end

        before do
          competences = [[Competence::ORGANISATION_METHODE, Competence::NIVEAU_4]]
          allow(restitution_globale).to receive(:niveaux_competences).and_return(competences)
          interpretations = [[Competence::ORGANISATION_METHODE, 4.0]]
          allow(restitution_globale).to receive(:interpretations_competences_transversales)
            .and_return(interpretations)
          allow(restitution_globale).to receive(:structure).and_return('structure')
          allow(restitution_globale).to receive(:synthese)
          allow(restitution_globale).to receive(:synthese_pre_positionnement)
          allow(restitution_globale).to receive(:synthese_positionnement)
          allow(restitution_globale).to receive(:synthese_positionnement_numeratie)
          allow(FabriqueRestitution).to receive(:restitution_globale)
            .and_return(restitution_globale)
          allow(restitution_globale).to receive(:selectionne_derniere_restitution)
        end

        describe 'affiche le niveau global de litteratie et numératie' do
          before do
            allow(restitution_globale).to receive(:interpretations_niveau2).and_return([])
          end

          it 'affiche deux niveaux différents pour litteratie et numératie CEFR' do
            mon_evaluation.update(niveau_cefr: :A1, niveau_cnef: :X1)
            visit admin_evaluation_path(mon_evaluation)
            expect(page).to have_xpath("//img[@alt='Niveau A1']")
            expect(page).to have_xpath("//img[@alt='Niveau X1']")
          end

          it 'affiche deux niveaux différents pour litteratie et numératie ANLCI' do
            mon_evaluation.update(niveau_anlci_litteratie: :profil3,
                                  niveau_anlci_numeratie: :profil4)
            visit admin_evaluation_path(mon_evaluation)
            expect(page).to have_xpath("//img[@alt='Niveau profil3']")
            expect(page).to have_xpath("//img[@alt='Niveau profil4']")
          end

          it "affiche que le score n'a pas pu être calculé" do
            mon_evaluation.update(niveau_cefr: nil, niveau_cnef: nil)
            visit admin_evaluation_path(mon_evaluation)
            expect(page).to have_content "Votre score n'a pas pu être calculé"
          end

          it "Socle cléa en cours d'acquisition" do
            allow(restitution_globale).to receive(:synthese_pre_positionnement)
              .and_return('socle_clea')
            visit admin_evaluation_path(mon_evaluation)
            expect(page).to have_content 'Certification Cléa indiquée'
          end

          it "Potentiellement en situation d'illettrisme" do
            allow(restitution_globale).to receive(:synthese_pre_positionnement)
              .and_return('illettrisme_potentiel')
            visit admin_evaluation_path(mon_evaluation)
            expect(page).to have_content 'Formation vivement recommandée'
          end
        end

        describe 'affiche le niveau des metacompétences' do
          it 'de litteratie et numératie' do
            allow(restitution_globale).to receive(:interpretations_niveau2)
              .with(:litteratie)
              .and_return([{ score_ccf: :palier0 }])
            allow(restitution_globale).to receive(:interpretations_niveau2)
              .with(:numeratie)
              .and_return([{ score_numeratie: :palier0 }])
            visit admin_evaluation_path(mon_evaluation)

            expect(page).to have_content 'Connaissance et compréhension du français'
            expect(page).to have_content 'des progrès à faire'

            expect(page).to have_content 'Compétences mathématiques'
          end
        end

        it "affiche l'évaluation en pdf" do
          allow(restitution_globale).to receive(:interpretations_niveau2).and_return([])
          visit admin_evaluation_path(mon_evaluation, format: :pdf)
          # rubocop:disable Lint/Debugger
          path = page.save_page
          # rubocop:enable Lint/Debugger

          reader = PDF::Reader.new(path)
          expect(reader.page(1).text).to include('Roger')
          expect(reader.page(1).text).to include('structure')
        end
      end
    end

    context "quand l'evaluation est terminée" do
      let(:evaluation_terminee) do
        create :evaluation,
               :terminee,
               campagne: ma_campagne
      end

      context 'Rôle admin' do
        let(:role) { 'admin' }

        before do
          mon_compte.update role: role
          visit admin_evaluation_path evaluation_terminee
        end

        it { expect(page).not_to have_content 'Terminée le' }
        it { expect(page).not_to have_content 'Temps total' }
      end

      context 'Rôle superadmin' do
        let(:role) { 'superadmin' }

        before do
          mon_compte.update role: role
          visit admin_evaluation_path evaluation_terminee
        end

        it { expect(page).to have_content 'Terminée le' }
        it { expect(page).to have_content 'Temps total' }
        it { expect(page).to have_content 'Statut' }
      end
    end

    context "quand l'évaluation est pour un parcours Evacob" do
      let(:evacob) { create :parcours_type, :evacob }
      let(:campagne_evacob) { create :campagne, parcours_type: evacob, compte: mon_compte }
      let(:evaluation) { create :evaluation, campagne: campagne_evacob }

      before do
        visit admin_evaluation_path(evaluation)
      end

      it { expect(page).not_to have_content 'Vos compétences en français et mathématiques' }
      it { expect(page).not_to have_content 'Correspondance avec l’ANLCI' }
    end

    describe 'suppression' do
      let(:evaluation) { create :evaluation, campagne: ma_campagne }
      let(:situation) { create :situation_tri }
      let!(:partie) { create :partie, situation: situation, evaluation: evaluation }
      let!(:evenement) { create :evenement, partie: partie }

      before { visit admin_evaluation_path(evaluation) }

      it do
        within('#action_items_sidebar_section') { click_on 'Supprimer' }
        expect(evaluation.reload.deleted?).to eq true
        expect(page.current_url).to eql(admin_campagne_url(ma_campagne))
      end
    end

    describe 'responsable de suivi' do
      let(:mon_collegue) { create :compte_admin, structure: mon_compte.structure }
      let(:evaluation) do
        create :evaluation, campagne: ma_campagne, responsable_suivi: mon_collegue
      end

      context "en tant qu'admin" do
        before { visit admin_evaluation_path(evaluation) }

        it "peut retirer l'assignation de n'importe quel collègue de ma structure" do
          within('#responsable_de_suivi_sidebar_section') do
            find('a.lien-supprimer').click
          end
          expect(page).not_to have_content(mon_collegue.email)
          expect(evaluation.reload.responsable_suivi).to eq nil
        end
      end

      context 'en tant que conseiller' do
        let!(:admin) { create :compte_admin, structure: mon_compte.structure }

        before do
          mon_compte.update(role: 'conseiller')
          visit admin_evaluation_path(evaluation)
        end

        it "peut retirer l'assignation de n'importe quel collègue de ma structure" do
          within('#responsable_de_suivi_sidebar_section') do
            find('a.lien-supprimer').click
          end
          expect(page).not_to have_content(mon_collegue.email)
          expect(evaluation.reload.responsable_suivi).to eq nil
        end
      end
    end
  end

  describe 'Edition' do
    let(:evaluation) { create :evaluation, campagne: ma_campagne, nom: 'Ancien nom' }
    let!(:mon_collegue) do
      create :compte_admin, structure: mon_compte.structure, prenom: 'Liam', nom: 'Mercier'
    end
    let!(:campagne_autre_structure) { create :campagne, libelle: 'Campagne autre structure' }
    let!(:collegue_autre_structure) do
      create :compte_conseiller,
             :structure_avec_admin,
             nom: 'collègue autre structure'
    end

    context 'Superadmin' do
      let(:role) { 'superadmin' }

      before do
        connecte(mon_compte)
        visit edit_admin_evaluation_path(evaluation)
        fill_in :evaluation_nom, with: 'Nouveau Nom'
      end

      context 'en changeant de campagne' do
        it do
          within('#evaluation_campagne_input') { select 'Campagne autre structure' }
          click_on 'Enregistrer'
          expect(evaluation.reload.nom).to eq 'Nouveau Nom'
          expect(evaluation.campagne.libelle).to eq 'Campagne autre structure'
        end
      end

      context 'sans mettre de campagne' do
        it do
          within('#evaluation_campagne_input') { select '' }
          click_on 'Enregistrer'
          expect(evaluation.reload.nom).to eq 'Ancien nom'
        end
      end

      context 'responsable de suivi' do
        it 'affiche les conseillers de la structure' do
          within('#evaluation_responsable_suivi_input') do
            expect(page).not_to have_content('collègue autre structure')
            expect(page).to have_content(mon_compte.nom_complet)
            expect(page).to have_content(mon_collegue.nom_complet)
          end
        end

        it 'peut modifier le responsable suivi' do
          within('#evaluation_responsable_suivi_input') do
            select mon_collegue.nom_complet
          end
          click_on 'Enregistrer'
          expect(evaluation.reload.responsable_suivi).to eq mon_collegue
        end
      end
    end

    context 'Admin' do
      let!(:campagne_meme_structure) do
        create :campagne, compte: mon_collegue, libelle: 'Campagne même structure'
      end

      before do
        connecte(mon_compte)
        visit edit_admin_evaluation_path(evaluation)
      end

      it "me permet de modifier la campagne parmi celles auxquelles j'ai accès" do
        within('#evaluation_campagne_input') do
          expect(page).not_to have_content('Campagne autre structure')
          select 'Campagne même structure'
        end
        click_on 'Enregistrer'
        expect(evaluation.reload.campagne.libelle).to eq 'Campagne même structure'
      end

      context 'responsable de suivi' do
        it 'affiche uniquement les conseillers de ma structure' do
          within('#evaluation_responsable_suivi_input') do
            expect(page).not_to have_content('collègue autre structure')
            expect(page).to have_content(mon_compte.nom_complet)
            expect(page).to have_content(mon_collegue.nom_complet)
          end
        end

        it 'peut modifier le responsable suivi' do
          within('#evaluation_responsable_suivi_input') do
            select mon_collegue.nom_complet
          end
          click_on 'Enregistrer'
          expect(evaluation.reload.responsable_suivi).to eq mon_collegue
        end
      end
    end
  end
end
