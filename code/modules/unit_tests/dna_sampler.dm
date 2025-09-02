/// Tests that DNA samplers can successfully sample animals without runtime errors
/datum/unit_test/dna_sampler_animals

/datum/unit_test/dna_sampler_animals/Run()
	var/mob/living/simple_animal/corgi/test_corgi = allocate(/mob/living/simple_animal/corgi)
	var/obj/item/dna_probe/sampler = allocate(/obj/item/dna_probe)
	var/mob/living/carbon/human/test_human = allocate(/mob/living/carbon/human)
	
	// Test that the sampler can sample the corgi without errors
	sampler.afterattack(test_corgi, test_human, TRUE)
	
	// Check that the animal data was added to the sampler
	TEST_ASSERT(sampler.animals[test_corgi.type], "DNA sampler failed to add animal data for corgi")
	
	// Test that sampling the same animal again gives the appropriate message
	var/initial_count = sampler.animals.len
	sampler.afterattack(test_corgi, test_human, TRUE)
	TEST_ASSERT(sampler.animals.len == initial_count, "DNA sampler should not add duplicate animal data")
	
	// Test with a simple mob without MOB_ORGANIC biotype to ensure it's rejected
	var/mob/living/simple_animal/bot/test_bot = allocate(/mob/living/simple_animal/bot)
	var/initial_count_before_bot = sampler.animals.len
	sampler.afterattack(test_bot, test_human, TRUE)
	TEST_ASSERT(sampler.animals.len == initial_count_before_bot, "DNA sampler should not sample non-organic mobs")
	
	// Test with a monkey (carbon mob)
	var/mob/living/carbon/human/species/monkey/test_monkey = allocate(/mob/living/carbon/human/species/monkey)
	sampler.afterattack(test_monkey, test_human, TRUE)
	TEST_ASSERT(sampler.animals[test_monkey.type], "DNA sampler failed to add animal data for monkey")