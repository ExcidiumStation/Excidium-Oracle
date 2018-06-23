/obj/item/book/killbook
	name = "����� ������"
	icon_state ="book"
	throw_speed = 1
	throw_range = 10
	author = "Forces beyond your comprehension"
	unique = 1
	title = "������� ��������!"
	dat = {"<html>
	<img src=https://i.imgur.com/s3CURZY.png width=350px height=350px> <br>
	������ �����:<br>
	"}

/obj/item/book/killbook/Initialize()
	..()
	icon_state = "book[rand(1,7)]"
	name = "������� [pick("��������","���������","��������")] [pick("�� ���������", "�� �������", "��� ������", "��� �����", "��� �����������", "��� �������")]"

/obj/item/book/killbook/attack_self(mob/user)
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		if(!H.undergoing_cardiac_arrest() && H.can_heartattack())
			H.set_heartattack(TRUE)
			if(H.stat == CONSCIOUS)
				H.visible_message("<span class='danger'>[H] ����! �� � ���!</span>")
			dat += "[H.real_name]<br>"
	if(!(ishuman(user)))
		user.visible_message("<span class='danger'>[user] ����! �� � ���!</span>")
		user.forceMove(src)
		dat += "[user.name]<br>"
	..()
